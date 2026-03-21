import { create } from 'zustand';
import { persist } from 'zustand/middleware';
import type { User } from '@domain/entities/User';
import { apiClient, setAuthFailureCallback, setTokenRefreshedCallback } from '@core/api/client';
import { ENDPOINTS } from '@core/api/endpoints';
import { TokenStorage } from '@core/storage/TokenStorage';
import { WebSocketClient } from '@core/websocket/WebSocketClient';
import type { LoginRequest, LoginResponse, RegisterRequest, RegisterResponse, UserResponse } from '@shared/types/api.types';
import axios from 'axios';

// 从后端UserResponse转换为前端User
function mapUserResponse(data: UserResponse): User {
  return {
    id: data.user_id,
    username: data.username,
    email: data.email,
    displayName: data.display_name || data.username,
    avatarUrl: data.avatar_url,
    createdAt: new Date(data.created_at),
    updatedAt: new Date(data.updated_at),
  };
}

// 从axios错误中提取错误信息
function extractErrorMessage(error: unknown, fallback: string): string {
  if (axios.isAxiosError(error) && error.response?.data?.error) {
    return error.response.data.error;
  }
  if (error instanceof Error) {
    return error.message;
  }
  return fallback;
}

interface AuthState {
  user: User | null;
  isAuthenticated: boolean;
  isLoading: boolean;
  isInitialized: boolean; // 标记 initializeAuth 是否已完成
  error: string | null;
  oauthLoading: {
    google: boolean;
    wechat: boolean;
  };
  
  // Actions
  login: (credentials: LoginRequest) => Promise<void>;
  register: (data: RegisterRequest) => Promise<void>;
  logout: () => Promise<void>;
  fetchCurrentUser: () => Promise<void>;
  clearError: () => void;
  initializeAuth: () => Promise<void>;
  loginWithGoogle: () => Promise<void>;
}

export const useAuthStore = create<AuthState>()(
  persist(
    (set, get) => ({
      user: null,
      isAuthenticated: false,
      isLoading: false,
      isInitialized: false,
      error: null,
      oauthLoading: {
        google: false,
        wechat: false,
      },

      login: async (credentials: LoginRequest) => {
        set({ isLoading: true, error: null });
        try {
          // 后端直接返回 {access_token, refresh_token, expires_in, token_type}
          const response = await apiClient.post<LoginResponse>(
            ENDPOINTS.AUTH.LOGIN,
            credentials
          );
          
          const { access_token, refresh_token, expires_in } = response.data;
          TokenStorage.setTokens(access_token, refresh_token, expires_in);
          
          // 设置WebSocket的Token提供者
          WebSocketClient.setTokenProvider(() => TokenStorage.getAccessToken());
          
          // 登录响应不包含用户信息，需要调用/auth/me获取
          const userResponse = await apiClient.get<UserResponse>(ENDPOINTS.AUTH.ME);
          const user = mapUserResponse(userResponse.data);
          
          WebSocketClient.connect();
          
          set({
            user,
            isAuthenticated: true,
            isLoading: false,
          });
        } catch (error) {
          const message = extractErrorMessage(error, '登录失败，请检查用户名和密码');
          set({ error: message, isLoading: false });
          throw error;
        }
      },

      register: async (data: RegisterRequest) => {
        set({ isLoading: true, error: null });
        try {
          // 后端注册不返回token，只返回 {user_id, username, message}
          await apiClient.post<RegisterResponse>(
            ENDPOINTS.AUTH.REGISTER,
            data
          );
          
          // 注册成功后自动登录
          const loginResponse = await apiClient.post<LoginResponse>(
            ENDPOINTS.AUTH.LOGIN,
            { username: data.username, password: data.password }
          );
          
          const { access_token, refresh_token } = loginResponse.data;
          TokenStorage.setTokens(access_token, refresh_token);
          
          // 设置WebSocket的Token提供者
          WebSocketClient.setTokenProvider(() => TokenStorage.getAccessToken());
          
          // 获取用户信息
          const userResponse = await apiClient.get<UserResponse>(ENDPOINTS.AUTH.ME);
          const user = mapUserResponse(userResponse.data);
          
          WebSocketClient.connect();
          
          set({
            user,
            isAuthenticated: true,
            isLoading: false,
          });
        } catch (error) {
          const message = extractErrorMessage(error, '注册失败，请稍后重试');
          set({ error: message, isLoading: false });
          throw error;
        }
      },

      logout: async () => {
        try {
          await apiClient.post(ENDPOINTS.AUTH.LOGOUT);
        } catch {
          // 忽略登出API错误
        } finally {
          TokenStorage.clearTokens();
          WebSocketClient.disconnect();
          set({
            user: null,
            isAuthenticated: false,
            error: null,
          });
        }
      },

      fetchCurrentUser: async () => {
        if (!TokenStorage.hasValidToken()) {
          return;
        }
        
        set({ isLoading: true });
        try {
          // 后端直接返回用户对象（无data包装）
          const response = await apiClient.get<UserResponse>(ENDPOINTS.AUTH.ME);
          set({
            user: mapUserResponse(response.data),
            isAuthenticated: true,
            isLoading: false,
          });
        } catch {
          // Token无效，清除状态
          TokenStorage.clearTokens();
          set({
            user: null,
            isAuthenticated: false,
            isLoading: false,
          });
        }
      },

      clearError: () => {
        set({ error: null });
      },

      initializeAuth: async () => {
        const { fetchCurrentUser } = get();
        
        // 设置Token刷新失败时的回调（用于自动登出）
        setAuthFailureCallback(() => {
          WebSocketClient.disconnect();
          useAuthStore.setState({
            user: null,
            isAuthenticated: false,
            isInitialized: true,
            error: null,
          });
          window.location.href = '/login';
        });

        // 设置Token刷新成功后的回调（用于WebSocket重连，保留订阅）
        setTokenRefreshedCallback(() => {
          // Token已刷新，WebSocket需要使用新Token重连（保留现有事件订阅）
          if (WebSocketClient.isConnected()) {
            WebSocketClient.disconnect();
            WebSocketClient.connect();
          }
        });
        
        if (TokenStorage.hasValidToken()) {
          // 设置WebSocket的Token提供者
          WebSocketClient.setTokenProvider(() => TokenStorage.getAccessToken());
          
          await fetchCurrentUser();
          
          // 如果认证成功，连接WebSocket
          if (get().isAuthenticated) {
            WebSocketClient.connect();
          }
        } else {
          // 无有效token，清除可能的过期持久化状态
          set({ user: null, isAuthenticated: false });
        }
        
        // 标记初始化完成
        set({ isInitialized: true });
      },

      loginWithGoogle: async () => {
        set({ 
          oauthLoading: { ...get().oauthLoading, google: true },
          error: null 
        });
        
        try {
          // 检查是否有 Google SDK
          if (!window.google) {
            throw new Error('Google SDK 未加载，请刷新页面重试');
          }

          // 使用 Google One Tap 登录
          const credential = await new Promise<string>((resolve, reject) => {
            window.google!.accounts.id.initialize({
              client_id: import.meta.env.VITE_GOOGLE_CLIENT_ID || '',
              callback: (response: { credential: string }) => {
                resolve(response.credential);
              },
            });
            window.google!.accounts.id.prompt((notification: { isNotDisplayed: () => boolean; isSkippedMoment: () => boolean }) => {
              if (notification.isNotDisplayed() || notification.isSkippedMoment()) {
                reject(new Error('Google 登录窗口无法显示'));
              }
            });
          });

          // 发送 credential 到后端验证
          const response = await apiClient.post<LoginResponse>(
            ENDPOINTS.AUTH.OAUTH_GOOGLE,
            { credential }
          );
          
          const { access_token, refresh_token, expires_in } = response.data;
          TokenStorage.setTokens(access_token, refresh_token, expires_in);
          WebSocketClient.setTokenProvider(() => TokenStorage.getAccessToken());
          
          // 获取用户信息
          const userResponse = await apiClient.get<UserResponse>(ENDPOINTS.AUTH.ME);
          const user = mapUserResponse(userResponse.data);
          
          WebSocketClient.connect();
          
          set({
            user,
            isAuthenticated: true,
            oauthLoading: { ...get().oauthLoading, google: false },
          });
        } catch (error) {
          const message = extractErrorMessage(error, 'Google 登录失败，请稍后重试');
          set({ 
            error: message, 
            oauthLoading: { ...get().oauthLoading, google: false } 
          });
          throw error;
        }
      },
    }),
    {
      name: 'auth-storage',
      partialize: (state) => ({
        // 只持久化用户信息，不持久化loading和error状态
        user: state.user,
        isAuthenticated: state.isAuthenticated,
      }),
    }
  )
);
