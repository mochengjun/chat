import { API_CONFIG, WS_CONFIG } from '@shared/constants/config';
import { WS_EVENTS, type WsEventType } from './events';
import type { WsMessage } from '@shared/types/api.types';

type EventCallback<T = unknown> = (data: T) => void;

// WebSocket 认证相关事件
const WS_AUTH_EVENTS = {
  AUTH_SUCCESS: 'auth_success',
  AUTH_FAILED: 'auth_failed',
} as const;

class WebSocketClientClass {
  private ws: WebSocket | null = null;
  private reconnectAttempts = 0;
  private heartbeatTimer: ReturnType<typeof setInterval> | null = null;
  private reconnectTimer: ReturnType<typeof setTimeout> | null = null;
  private eventHandlers = new Map<string, Set<EventCallback>>();
  private messageQueue: WsMessage[] = [];
  private isConnecting = false;
  private isAuthenticated = false;
  private pendingMessages: WsMessage[] = [];
  private tokenProvider: (() => string | null) | null = null;

  // 设置Token提供者
  setTokenProvider(provider: () => string | null): void {
    this.tokenProvider = provider;
  }

  // 连接WebSocket
  connect(): void {
    if (this.ws?.readyState === WebSocket.OPEN || this.isConnecting) {
      return;
    }

    const token = this.tokenProvider?.();
    if (!token) {
      console.warn('WebSocket: No token available');
      return;
    }

    this.isConnecting = true;
    this.isAuthenticated = false;
    // 不再在 URL 中传递 token，改为连接后通过消息发送
    const wsUrl = API_CONFIG.WS_URL;
    
    try {
      this.ws = new WebSocket(wsUrl);
      this.setupEventListeners(token);
    } catch (error) {
      console.error('WebSocket connection error:', error);
      this.isConnecting = false;
      this.handleReconnect();
    }
  }

  // 设置WebSocket事件监听
  private setupEventListeners(token: string): void {
    if (!this.ws) return;

    this.ws.onopen = () => {
      console.log('WebSocket connected, sending auth message');
      this.isConnecting = false;
      this.reconnectAttempts = 0;
      // 连接成功后立即发送认证消息
      this.sendAuthMessage(token);
    };

    this.ws.onmessage = (event: MessageEvent) => {
      try {
        // 类型检查：确保消息是字符串类型
        if (typeof event.data !== 'string') {
          console.warn('[WebSocket] Received non-string message, ignoring');
          return;
        }

        // 后端可能会合并多条消息用换行符分隔发送，需要分割处理
        const rawData = event.data;
        const messages = rawData.split('\n').filter(line => line.trim());
        
        for (const msgStr of messages) {
          try {
            const data = JSON.parse(msgStr) as WsMessage;
            
            // 处理心跳响应
            if (data.type === WS_EVENTS.PONG) {
              continue;
            }
            
            // 处理认证成功
            if (data.type === WS_AUTH_EVENTS.AUTH_SUCCESS) {
              console.log('WebSocket authentication successful');
              this.isAuthenticated = true;
              this.startHeartbeat();
              this.flushPendingMessages();
              this.emit(WS_EVENTS.CONNECTED, null);
              continue;
            }
            
            // 处理认证失败
            if (data.type === WS_AUTH_EVENTS.AUTH_FAILED) {
              console.error('WebSocket authentication failed:', data.payload);
              this.isAuthenticated = false;
              this.ws?.close(1008, 'Authentication failed');
              this.emit(WS_EVENTS.ERROR, { type: 'auth_failed', payload: data.payload });
              continue;
            }
            
            // 触发对应事件
            this.emit(data.type, data.payload);
          } catch (parseError) {
            console.error('WebSocket message parse error:', parseError, 'Raw:', msgStr);
          }
        }
      } catch (error) {
        console.error('WebSocket message handling error:', error);
      }
    };

    this.ws.onerror = (event: Event) => {
      console.error('WebSocket error:', event);
      this.isConnecting = false;
      this.emit(WS_EVENTS.ERROR, event);
    };

    this.ws.onclose = (event: CloseEvent) => {
      console.log('WebSocket closed:', event.code, event.reason);
      this.isConnecting = false;
      this.isAuthenticated = false;
      this.stopHeartbeat();
      this.emit(WS_EVENTS.DISCONNECTED, { code: event.code, reason: event.reason });
      this.handleReconnect();
    };
  }

  // 发送认证消息
  private sendAuthMessage(token: string): void {
    const authMessage: WsMessage = {
      type: 'auth',
      payload: { token },
      timestamp: new Date().toISOString(),
    };
    if (this.ws?.readyState === WebSocket.OPEN) {
      this.ws.send(JSON.stringify(authMessage));
    }
  }

  // 发送消息
  send<T>(type: string, payload: T): void {
    const message: WsMessage<T> = {
      type,
      payload,
      timestamp: new Date().toISOString(),
    };

    // 如果未认证且不是认证消息，缓存到待发送队列
    if (!this.isAuthenticated && type !== 'auth') {
      this.pendingMessages.push(message as WsMessage);
      return;
    }

    if (this.ws?.readyState === WebSocket.OPEN) {
      this.ws.send(JSON.stringify(message));
    } else {
      // 离线时加入队列
      this.messageQueue.push(message as WsMessage);
    }
  }

  // 发送消息（原始格式）
  sendRaw(message: WsMessage): void {
    // 如果未认证且不是认证消息，缓存到待发送队列
    if (!this.isAuthenticated && message.type !== 'auth') {
      this.pendingMessages.push(message);
      return;
    }

    if (this.ws?.readyState === WebSocket.OPEN) {
      this.ws.send(JSON.stringify(message));
    } else {
      this.messageQueue.push(message);
    }
  }

  // 订阅事件
  subscribe<T = unknown>(event: WsEventType | string, callback: EventCallback<T>): () => void {
    if (!this.eventHandlers.has(event)) {
      this.eventHandlers.set(event, new Set());
    }
    this.eventHandlers.get(event)!.add(callback as EventCallback);

    // 返回取消订阅函数
    return () => {
      this.unsubscribe(event, callback as EventCallback);
    };
  }

  // 取消订阅
  unsubscribe(event: WsEventType | string, callback: EventCallback): void {
    this.eventHandlers.get(event)?.delete(callback);
  }

  // 触发事件
  private emit<T>(event: string, data: T): void {
    this.eventHandlers.get(event)?.forEach(handler => {
      try {
        handler(data);
      } catch (error) {
        console.error(`WebSocket event handler error for ${event}:`, error);
      }
    });
  }

  // 开始心跳
  private startHeartbeat(): void {
    // 先确保清理旧计时器
    if (this.heartbeatTimer) {
      clearInterval(this.heartbeatTimer);
      this.heartbeatTimer = null;
    }

    this.heartbeatTimer = setInterval(() => {
      if (this.ws?.readyState === WebSocket.OPEN) {
        this.send(WS_EVENTS.PING, {});
      } else {
        // WebSocket 不在 OPEN 状态，停止心跳
        this.stopHeartbeat();
      }
    }, WS_CONFIG.HEARTBEAT_INTERVAL);
  }

  // 停止心跳
  private stopHeartbeat(): void {
    if (this.heartbeatTimer) {
      clearInterval(this.heartbeatTimer);
      this.heartbeatTimer = null;
    }
  }

  // 处理重连
  private handleReconnect(): void {
    if (this.reconnectTimer) {
      return;
    }

    if (this.reconnectAttempts >= WS_CONFIG.MAX_RECONNECT_ATTEMPTS) {
      console.log('WebSocket: Max reconnect attempts reached');
      this.emit(WS_EVENTS.DISCONNECTED, { permanent: true });
      return;
    }

    const delay = WS_CONFIG.RECONNECT_DELAY * Math.pow(1.5, this.reconnectAttempts);
    this.reconnectAttempts++;
    
    console.log(`WebSocket: Reconnecting in ${delay}ms (attempt ${this.reconnectAttempts})`);
    this.emit(WS_EVENTS.RECONNECTING, { attempt: this.reconnectAttempts });

    this.reconnectTimer = setTimeout(() => {
      this.reconnectTimer = null;
      this.connect();
    }, delay);
  }

  // 刷新待发送消息队列（认证成功后调用）
  private flushPendingMessages(): void {
    while (this.pendingMessages.length > 0) {
      const message = this.pendingMessages.shift();
      if (message && this.ws?.readyState === WebSocket.OPEN) {
        this.ws.send(JSON.stringify(message));
      }
    }
  }

  // 断开连接
  disconnect(): void {
    this.stopHeartbeat();
    
    if (this.reconnectTimer) {
      clearTimeout(this.reconnectTimer);
      this.reconnectTimer = null;
    }

    if (this.ws) {
      this.ws.close(1000, 'Client disconnect');
      this.ws = null;
    }

    this.reconnectAttempts = 0;
    this.messageQueue = [];
    this.pendingMessages = [];
    this.isAuthenticated = false;
  }

  // 获取连接状态
  isConnected(): boolean {
    return this.ws?.readyState === WebSocket.OPEN && this.isAuthenticated;
  }

  // 获取连接状态
  getReadyState(): number {
    return this.ws?.readyState ?? WebSocket.CLOSED;
  }

  // 获取认证状态
  isAuthenticated_(): boolean {
    return this.isAuthenticated;
  }
}

export const WebSocketClient = new WebSocketClientClass();
