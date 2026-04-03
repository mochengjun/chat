import axios from 'axios';
import type { AxiosInstance, InternalAxiosRequestConfig, AxiosResponse, AxiosError } from 'axios';
import { API_CONFIG } from '@shared/constants/config';
import { TokenStorage } from '@core/storage/TokenStorage';
import { ENDPOINTS } from './endpoints';
import type { LoginResponse } from '@shared/types/api.types';
import { requestCache } from '@core/cache/RequestCache';
import { concurrencyController } from '@core/network/ConcurrencyController';

// 创建Axios实例
const apiClient: AxiosInstance = axios.create({
  baseURL: API_CONFIG.BASE_URL,
  timeout: API_CONFIG.TIMEOUT,
  headers: {
    'Content-Type': 'application/json',
  },
});

// 是否正在刷新Token
let isRefreshing = false;
// 等待Token刷新的请求队列 - 存储resolve和reject回调
let refreshSubscribers: {
  resolve: (token: string) => void;
  reject: (error: Error) => void;
}[] = [];

// 登出回调（由authStore设置）
let onAuthFailureCallback: (() => void) | null = null;

// Token刷新成功回调（用于通知WebSocket重连）
let onTokenRefreshedCallback: ((token: string) => void) | null = null;

// 设置认证失败回调
const setAuthFailureCallback = (callback: () => void): void => {
  onAuthFailureCallback = callback;
};

// 设置Token刷新成功回调
const setTokenRefreshedCallback = (callback: (token: string) => void): void => {
  onTokenRefreshedCallback = callback;
};

// 订阅Token刷新
const subscribeTokenRefresh = (): Promise<string> => {
  return new Promise((resolve, reject) => {
    refreshSubscribers.push({ resolve, reject });
  });
};

// 通知所有订阅者 - Token刷新成功
const onTokenRefreshed = (token: string) => {
  refreshSubscribers.forEach(({ resolve }) => resolve(token));
  refreshSubscribers = [];
  // 通知外部Token已刷新（用于WebSocket重连等）
  onTokenRefreshedCallback?.(token);
};

// 通知刷新失败 - 拒绝所有等待的Promise
const onTokenRefreshFailed = (error: Error) => {
  refreshSubscribers.forEach(({ reject }) => reject(error));
  refreshSubscribers = [];
};

// 执行Token刷新
async function refreshAccessToken(): Promise<string> {
  const refreshToken = TokenStorage.getRefreshToken();
  if (!refreshToken) {
    throw new Error('No refresh token');
  }

  // 使用独立的axios实例，避免触发拦截器循环
  const response = await axios.post<LoginResponse>(
    `${API_CONFIG.BASE_URL}${ENDPOINTS.AUTH.REFRESH}`,
    { refresh_token: refreshToken }
  );

  const { access_token, refresh_token, expires_in } = response.data;
  TokenStorage.setTokens(access_token, refresh_token, expires_in);
  
  return access_token;
}

// 主动刷新Token（在Token即将过期时调用）
async function proactiveTokenRefresh(): Promise<string | null> {
  if (isRefreshing) {
    // 如果已经在刷新，等待刷新完成
    try {
      return await subscribeTokenRefresh();
    } catch {
      // 刷新失败，返回当前Token让请求继续（会触发401处理）
      return TokenStorage.getAccessToken();
    }
  }

  if (!TokenStorage.isTokenExpiringSoon()) {
    // Token未即将过期，直接返回当前Token
    return TokenStorage.getAccessToken();
  }

  isRefreshing = true;

  try {
    const newToken = await refreshAccessToken();
    onTokenRefreshed(newToken);
    return newToken;
  } catch {
    onTokenRefreshFailed(new Error('Proactive token refresh failed'));
    // 主动刷新失败不立即跳转登录，让后续请求触发401处理
    return TokenStorage.getAccessToken();
  } finally {
    isRefreshing = false;
  }
}

// 缓存装饰器（仅用于 GET 请求）
const cachedGet = <T>(url: string, params?: any, ttl: number = 5 * 60 * 1000): Promise<T> => {
  // 检查缓存
  const cachedData = requestCache.get<T>(url, params);
  if (cachedData) {
    if (import.meta.env.DEV) {
      console.log('[API] Cache hit');
    }
    return Promise.resolve(cachedData);
  }

  // 通过并发控制器发起请求
  return concurrencyController.wrap(async () => {
    const response = await apiClient.get<T>(url, { params });
    // 缓存响应数据
    requestCache.set(url, response.data, ttl, params);
    return response.data;
  });
};

// 请求拦截器：添加Authorization Header，并主动刷新即将过期的Token
apiClient.interceptors.request.use(
  async (config: InternalAxiosRequestConfig) => {
    // 跳过认证相关的接口
    if (config.url?.includes('/auth/login') || 
        config.url?.includes('/auth/register') ||
        config.url?.includes('/auth/refresh')) {
      return config;
    }

    // 检查Token是否即将过期，如果是则主动刷新
    if (TokenStorage.hasValidToken() && TokenStorage.isTokenExpiringSoon()) {
      await proactiveTokenRefresh();
    }

    const token = TokenStorage.getAccessToken();
    if (token && config.headers) {
      config.headers.Authorization = `Bearer ${token}`;
    }
    return config;
  },
  (error: AxiosError) => {
    return Promise.reject(error);
  }
);

// 响应拦截器：处理401错误和Token刷新（作为主动刷新的后备机制）
apiClient.interceptors.response.use(
  (response: AxiosResponse) => {
    return response;
  },
  async (error: AxiosError) => {
    const originalRequest = error.config as InternalAxiosRequestConfig & { _retry?: boolean };
    
    // 如果是401错误且未重试过
    if (error.response?.status === 401 && !originalRequest._retry) {
      // 如果是登录或刷新接口，直接返回错误
      if (originalRequest.url?.includes('/auth/login') || 
          originalRequest.url?.includes('/auth/refresh')) {
        return Promise.reject(error);
      }

      if (isRefreshing) {
        // 如果正在刷新，等待刷新完成后重试
        try {
          const token = await subscribeTokenRefresh();
          if (originalRequest.headers) {
            originalRequest.headers.Authorization = `Bearer ${token}`;
          }
          return apiClient(originalRequest);
        } catch (refreshError) {
          // 刷新失败，拒绝原请求
          return Promise.reject(refreshError);
        }
      }

      originalRequest._retry = true;
      isRefreshing = true;

      try {
        const newToken = await refreshAccessToken();
        onTokenRefreshed(newToken);
        
        // 重试原请求
        if (originalRequest.headers) {
          originalRequest.headers.Authorization = `Bearer ${newToken}`;
        }
        return apiClient(originalRequest);
      } catch (refreshError) {
        const authError = new Error('Token refresh failed');
        onTokenRefreshFailed(authError);
        // 刷新失败，清除Token并通知authStore
        TokenStorage.clearTokens();
        // 使用回调通知authStore进行登出处理
        if (onAuthFailureCallback) {
          onAuthFailureCallback();
        } else {
          // 降级：直接跳转登录页
          window.location.href = '/login';
        }
        return Promise.reject(refreshError);
      } finally {
        isRefreshing = false;
      }
    }

    return Promise.reject(error);
  }
);

export { apiClient, setAuthFailureCallback, setTokenRefreshedCallback, cachedGet };
