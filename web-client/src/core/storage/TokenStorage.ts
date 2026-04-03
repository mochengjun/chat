import { TOKEN_CONFIG } from '@shared/constants/config';

// Token存储键名
const TOKEN_EXPIRY_KEY = 'sec_chat_token_expiry';

// 提前刷新Token的时间阈值（Token过期前5分钟刷新）
const REFRESH_THRESHOLD_MS = 5 * 60 * 1000;

class TokenStorageClass {
  private accessToken: string | null = null;

  // 获取AccessToken（优先从内存，其次从sessionStorage）
  getAccessToken(): string | null {
    if (this.accessToken) {
      return this.accessToken;
    }
    // 降级到sessionStorage（页面刷新后）
    return sessionStorage.getItem(TOKEN_CONFIG.ACCESS_TOKEN_KEY);
  }

  // 设置AccessToken（存内存 + sessionStorage）
  setAccessToken(token: string): void {
    this.accessToken = token;
    sessionStorage.setItem(TOKEN_CONFIG.ACCESS_TOKEN_KEY, token);
  }

  // 获取RefreshToken
  getRefreshToken(): string | null {
    return sessionStorage.getItem(TOKEN_CONFIG.REFRESH_TOKEN_KEY);
  }

  // 设置RefreshToken
  setRefreshToken(token: string): void {
    sessionStorage.setItem(TOKEN_CONFIG.REFRESH_TOKEN_KEY, token);
  }

  // 设置Token过期时间（单位：秒）
  setTokenExpiry(expiresIn: number): void {
    const expiryTime = Date.now() + expiresIn * 1000;
    sessionStorage.setItem(TOKEN_EXPIRY_KEY, expiryTime.toString());
  }

  // 获取Token过期时间戳
  getTokenExpiry(): number | null {
    const expiry = sessionStorage.getItem(TOKEN_EXPIRY_KEY);
    return expiry ? parseInt(expiry, 10) : null;
  }

  // 设置所有Token
  setTokens(accessToken: string, refreshToken: string, expiresIn?: number): void {
    this.setAccessToken(accessToken);
    this.setRefreshToken(refreshToken);
    if (expiresIn) {
      this.setTokenExpiry(expiresIn);
    } else {
      // 默认使用配置中的过期时间
      this.setTokenExpiry(TOKEN_CONFIG.ACCESS_TOKEN_EXPIRES / 1000);
    }
  }

  // 清除所有Token
  clearTokens(): void {
    this.accessToken = null;
    // 清理sessionStorage
    sessionStorage.removeItem(TOKEN_CONFIG.ACCESS_TOKEN_KEY);
    sessionStorage.removeItem(TOKEN_CONFIG.REFRESH_TOKEN_KEY);
    sessionStorage.removeItem(TOKEN_EXPIRY_KEY);
    // 清理遗留的localStorage数据（向后兼容迁移）
    localStorage.removeItem(TOKEN_CONFIG.ACCESS_TOKEN_KEY);
    localStorage.removeItem(TOKEN_CONFIG.REFRESH_TOKEN_KEY);
    localStorage.removeItem(TOKEN_EXPIRY_KEY);
  }

  // 检查是否有有效Token
  hasValidToken(): boolean {
    return !!this.getAccessToken();
  }

  // 检查是否有RefreshToken
  hasRefreshToken(): boolean {
    return !!this.getRefreshToken();
  }

  // 检查Token是否即将过期（在阈值内）
  isTokenExpiringSoon(): boolean {
    const expiry = this.getTokenExpiry();
    if (!expiry) {
      // 如果没有过期时间信息，假设不需要刷新
      return false;
    }
    const timeUntilExpiry = expiry - Date.now();
    return timeUntilExpiry > 0 && timeUntilExpiry <= REFRESH_THRESHOLD_MS;
  }

  // 检查Token是否已过期
  isTokenExpired(): boolean {
    const expiry = this.getTokenExpiry();
    if (!expiry) {
      // 如果没有过期时间信息，假设未过期（由服务端判断）
      return false;
    }
    return Date.now() >= expiry;
  }

  // 获取距离Token过期的剩余时间（毫秒）
  getTimeUntilExpiry(): number {
    const expiry = this.getTokenExpiry();
    if (!expiry) {
      return Infinity;
    }
    return Math.max(0, expiry - Date.now());
  }
}

export const TokenStorage = new TokenStorageClass();
