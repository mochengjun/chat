package handler

import (
	"encoding/json"
	"log"
	"net/http"
	"sync"
	"time"

	"sec-chat/auth-service/internal/middleware"
	"sec-chat/auth-service/internal/service"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/gorilla/websocket"
)

var upgrader = websocket.Upgrader{
	ReadBufferSize:  1024,
	WriteBufferSize: 1024,
	CheckOrigin:     CheckWebSocketOrigin,
}

// WSMessage WebSocket 消息
type WSMessage struct {
	Type    string      `json:"type"`
	Payload interface{} `json:"payload,omitempty"`
}

// WSClient WebSocket 客户端
type WSClient struct {
	hub      *WSHub
	conn     *websocket.Conn
	userID   string
	connID   string // 唯一连接标识，支持同一用户多设备
	deviceID string // 设备标识（可选，由客户端提供）
	send     chan []byte
	rooms    map[string]bool
	roomsMux sync.RWMutex
}

// WSHub WebSocket Hub 管理所有连接
type WSHub struct {
	// 支持同一用户多设备连接: userID -> connID -> client
	clients map[string]map[string]*WSClient
	// 房间连接: roomID -> userID -> connID -> client
	rooms       map[string]map[string]map[string]*WSClient
	broadcast   chan *BroadcastMessage
	register    chan *WSClient
	unregister  chan *WSClient
	joinRoom    chan *RoomAction
	leaveRoom   chan *RoomAction
	mu          sync.RWMutex
	chatService service.ChatService

	// 在线状态相关
	offlineTimers map[string]*time.Timer // userID -> 离线延迟计时器
	offlineGrace  time.Duration          // 离线宽限期，用于处理短暂断线重连
}

// BroadcastMessage 广播消息
type BroadcastMessage struct {
	RoomID  string
	Message []byte
}

// RoomAction 房间操作
type RoomAction struct {
	Client *WSClient
	RoomID string
}

// NewWSHub 创建 WebSocket Hub
func NewWSHub(chatService service.ChatService) *WSHub {
	hub := &WSHub{
		clients:       make(map[string]map[string]*WSClient),
		rooms:         make(map[string]map[string]map[string]*WSClient),
		broadcast:     make(chan *BroadcastMessage, 256),
		register:      make(chan *WSClient),
		unregister:    make(chan *WSClient),
		joinRoom:      make(chan *RoomAction),
		leaveRoom:     make(chan *RoomAction),
		chatService:   chatService,
		offlineTimers: make(map[string]*time.Timer),
		offlineGrace:  30 * time.Second, // 30秒宽限期，处理短暂断线重连
	}
	// 将 Hub 注册为在线状态追踪器
	chatService.SetPresenceTracker(hub)
	return hub
}

// Run 运行 Hub
func (h *WSHub) Run() {
	for {
		select {
		case client := <-h.register:
			h.mu.Lock()
			// 如果有离线宽限期计时器，取消它（用户重连了）
			if timer, ok := h.offlineTimers[client.userID]; ok {
				timer.Stop()
				delete(h.offlineTimers, client.userID)
				log.Printf("User %s reconnected within grace period", middleware.MaskUserID(client.userID))
			}

			// 初始化用户的连接映射（如果不存在）
			if _, ok := h.clients[client.userID]; !ok {
				h.clients[client.userID] = make(map[string]*WSClient)
			}
			wasOnline := len(h.clients[client.userID]) > 0
			// 添加新连接（支持多设备）
			h.clients[client.userID][client.connID] = client
			h.mu.Unlock()

			// 标记上线
			h.chatService.SetUserOnline(client.userID)

			// 上线广播延迟到 HandleWebSocket 中加入房间之后执行
			_ = wasOnline

			log.Printf("WebSocket client registered: user=%s conn=%s (total connections: %d)",
				middleware.MaskUserID(client.userID), client.connID[:8], len(h.clients[client.userID]))

		case client := <-h.unregister:
			h.mu.Lock()
			if userClients, ok := h.clients[client.userID]; ok {
				if _, exists := userClients[client.connID]; exists {
					// 在清理前保存用户的房间列表，供离线通知使用
					client.roomsMux.RLock()
					userRoomIDs := make([]string, 0, len(client.rooms))
					for roomID := range client.rooms {
						userRoomIDs = append(userRoomIDs, roomID)
					}
					client.roomsMux.RUnlock()

					// 删除这个连接
					delete(userClients, client.connID)
					close(client.send)

					// 从所有房间移除这个连接
					for _, roomID := range userRoomIDs {
						if roomClients, ok := h.rooms[roomID]; ok {
							if userConns, ok := roomClients[client.userID]; ok {
								delete(userConns, client.connID)
								if len(userConns) == 0 {
									delete(roomClients, client.userID)
								}
							}
						}
					}

					// 如果该用户没有其他连接了，启动离线宽限期计时器
					if len(userClients) == 0 {
						delete(h.clients, client.userID)
						userID := client.userID
						savedRoomIDs := userRoomIDs
						h.offlineTimers[userID] = time.AfterFunc(h.offlineGrace, func() {
							h.mu.Lock()
							// 再次检查用户是否已重连
							if _, stillOnline := h.clients[userID]; !stillOnline || len(h.clients[userID]) == 0 {
								delete(h.offlineTimers, userID)
								h.mu.Unlock()

								// 宽限期结束且未重连，标记离线
								h.chatService.SetUserOffline(userID)
								h.broadcastPresenceToRooms(userID, savedRoomIDs, false)
								log.Printf("User %s marked offline after grace period", middleware.MaskUserID(userID))
							} else {
								delete(h.offlineTimers, userID)
								h.mu.Unlock()
							}
						})
					}
				}
			}
			h.mu.Unlock()
			log.Printf("WebSocket client unregistered: user=%s conn=%s", middleware.MaskUserID(client.userID), client.connID[:8])

		case action := <-h.joinRoom:
			h.mu.Lock()
			// 初始化房间映射
			if _, ok := h.rooms[action.RoomID]; !ok {
				h.rooms[action.RoomID] = make(map[string]map[string]*WSClient)
			}
			if _, ok := h.rooms[action.RoomID][action.Client.userID]; !ok {
				h.rooms[action.RoomID][action.Client.userID] = make(map[string]*WSClient)
			}
			h.rooms[action.RoomID][action.Client.userID][action.Client.connID] = action.Client
			h.mu.Unlock()
			action.Client.roomsMux.Lock()
			action.Client.rooms[action.RoomID] = true
			action.Client.roomsMux.Unlock()
			log.Printf("Client %s (conn=%s) joined room %s", middleware.MaskUserID(action.Client.userID), action.Client.connID[:8], action.RoomID)

		case action := <-h.leaveRoom:
			h.mu.Lock()
			if roomClients, ok := h.rooms[action.RoomID]; ok {
				if userConns, ok := roomClients[action.Client.userID]; ok {
					delete(userConns, action.Client.connID)
					if len(userConns) == 0 {
						delete(roomClients, action.Client.userID)
					}
				}
			}
			h.mu.Unlock()
			action.Client.roomsMux.Lock()
			delete(action.Client.rooms, action.RoomID)
			action.Client.roomsMux.Unlock()

		case msg := <-h.broadcast:
			h.mu.RLock()
			if roomClients, ok := h.rooms[msg.RoomID]; ok {
				// 遍历房间内所有用户的所有连接
				for _, userConns := range roomClients {
					for _, client := range userConns {
						select {
						case client.send <- msg.Message:
						default:
							// 发送缓冲区满，跳过
						}
					}
				}
			}
			h.mu.RUnlock()
		}
	}
}

// BroadcastToRoom 向房间广播消息
func (h *WSHub) BroadcastToRoom(roomID string, msg WSMessage) {
	data, err := json.Marshal(msg)
	if err != nil {
		return
	}
	h.broadcast <- &BroadcastMessage{
		RoomID:  roomID,
		Message: data,
	}
}

// BroadcastToUser 向用户的所有设备发送消息
func (h *WSHub) BroadcastToUser(userID string, msg WSMessage) {
	data, err := json.Marshal(msg)
	if err != nil {
		return
	}
	h.mu.RLock()
	if userClients, ok := h.clients[userID]; ok {
		// 向用户的所有连接发送消息
		for _, client := range userClients {
			select {
			case client.send <- data:
			default:
				// 发送缓冲区满，跳过
			}
		}
	}
	h.mu.RUnlock()
}

// HandleWebSocket 处理 WebSocket 连接
func (h *WSHub) HandleWebSocket(c *gin.Context) {
	userID := c.GetString("user_id")
	if userID == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	// 从查询参数获取设备ID（可选）
	deviceID := c.Query("device_id")

	conn, err := upgrader.Upgrade(c.Writer, c.Request, nil)
	if err != nil {
		log.Printf("WebSocket upgrade error: %v", err)
		return
	}

	// 为每个连接生成唯一ID
	connID := uuid.New().String()

	client := &WSClient{
		hub:      h,
		conn:     conn,
		userID:   userID,
		connID:   connID,
		deviceID: deviceID,
		send:     make(chan []byte, 256),
		rooms:    make(map[string]bool),
	}

	h.register <- client

	// 加入用户的所有房间
	rooms, err := h.chatService.GetUserRooms(c.Request.Context(), userID)
	if err == nil {
		roomIDs := make([]string, 0, len(rooms))
		for _, room := range rooms {
			h.joinRoom <- &RoomAction{Client: client, RoomID: room.ID}
			roomIDs = append(roomIDs, room.ID)
		}
		// 房间加入操作已入队，广播上线状态到用户的所有房间
		h.broadcastPresenceToRooms(userID, roomIDs, true)
	}

	go client.writePump()
	go client.readPump()
}

// readPump 读取消息
func (c *WSClient) readPump() {
	defer func() {
		c.hub.unregister <- c
		c.conn.Close()
	}()

	c.conn.SetReadLimit(512 * 1024) // 512KB
	c.conn.SetReadDeadline(time.Now().Add(60 * time.Second))
	c.conn.SetPongHandler(func(string) error {
		c.conn.SetReadDeadline(time.Now().Add(60 * time.Second))
		return nil
	})

	for {
		_, message, err := c.conn.ReadMessage()
		if err != nil {
			if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway, websocket.CloseAbnormalClosure) {
				log.Printf("WebSocket read error: %v", err)
			}
			break
		}

		// 解析消息
		var msg WSMessage
		if err := json.Unmarshal(message, &msg); err != nil {
			continue
		}

		// 处理不同类型的消息
		switch msg.Type {
		case "ping":
			// 回复 pong
			data, _ := json.Marshal(WSMessage{Type: "pong"})
			c.send <- data

		case "join_room":
			if roomID, ok := msg.Payload.(string); ok {
				c.hub.joinRoom <- &RoomAction{Client: c, RoomID: roomID}
			}

		case "leave_room":
			if roomID, ok := msg.Payload.(string); ok {
				c.hub.leaveRoom <- &RoomAction{Client: c, RoomID: roomID}
			}

		case "typing":
			// 转发 typing 事件到房间
			if payload, ok := msg.Payload.(map[string]interface{}); ok {
				if roomID, ok := payload["room_id"].(string); ok {
					c.hub.BroadcastToRoom(roomID, WSMessage{
						Type: "typing",
						Payload: map[string]interface{}{
							"user_id": c.userID,
							"room_id": roomID,
						},
					})
				}
			}
		}
	}
}

// writePump 写入消息
func (c *WSClient) writePump() {
	ticker := time.NewTicker(30 * time.Second)
	defer func() {
		ticker.Stop()
		c.conn.Close()
	}()

	for {
		select {
		case message, ok := <-c.send:
			c.conn.SetWriteDeadline(time.Now().Add(10 * time.Second))
			if !ok {
				c.conn.WriteMessage(websocket.CloseMessage, []byte{})
				return
			}

			w, err := c.conn.NextWriter(websocket.TextMessage)
			if err != nil {
				return
			}
			w.Write(message)

			// 合并发送队列中的消息
			n := len(c.send)
			for i := 0; i < n; i++ {
				w.Write([]byte{'\n'})
				w.Write(<-c.send)
			}

			if err := w.Close(); err != nil {
				return
			}

		case <-ticker.C:
			c.conn.SetWriteDeadline(time.Now().Add(10 * time.Second))
			if err := c.conn.WriteMessage(websocket.PingMessage, nil); err != nil {
				return
			}
		}
	}
}

// === UserPresenceTracker 接口实现 ===

// IsUserOnline 检查用户是否在线（实现 service.UserPresenceTracker 接口）
func (h *WSHub) IsUserOnline(userID string) bool {
	h.mu.RLock()
	defer h.mu.RUnlock()
	userClients, ok := h.clients[userID]
	return ok && len(userClients) > 0
}

// GetOnlineUserIDs 批量查询在线用户（实现 service.UserPresenceTracker 接口）
func (h *WSHub) GetOnlineUserIDs(userIDs []string) map[string]bool {
	h.mu.RLock()
	defer h.mu.RUnlock()
	result := make(map[string]bool, len(userIDs))
	for _, uid := range userIDs {
		userClients, ok := h.clients[uid]
		result[uid] = ok && len(userClients) > 0
	}
	return result
}

// GetUserConnectionCount 获取用户的连接数量
func (h *WSHub) GetUserConnectionCount(userID string) int {
	h.mu.RLock()
	defer h.mu.RUnlock()
	if userClients, ok := h.clients[userID]; ok {
		return len(userClients)
	}
	return 0
}

// broadcastPresenceToRooms 向指定房间列表广播用户在线状态变更
func (h *WSHub) broadcastPresenceToRooms(userID string, roomIDs []string, online bool) {
	statusType := "user_offline"
	if online {
		statusType = "user_online"
	}

	msg := WSMessage{
		Type: statusType,
		Payload: map[string]interface{}{
			"user_id": userID,
			"online":  online,
		},
	}

	for _, roomID := range roomIDs {
		h.BroadcastToRoom(roomID, msg)
	}
}
