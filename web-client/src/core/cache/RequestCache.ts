/**
 * 请求缓存管理器
 * 支持内存缓存和本地存储缓存
 */

interface CacheItem<T> {
  data: T;
  timestamp: number;
  ttl: number; // Time to live in milliseconds
}

class RequestCache {
  private memoryCache: Map<string, CacheItem<any>> = new Map();
  private readonly storageKey = 'request_cache';
  private maxMemoryItems = 100; // 最大内存缓存项

  constructor() {
    // 从 localStorage 恢复缓存
    this.loadFromStorage();
    
    // 定期清理过期缓存
    setInterval(() => this.cleanup(), 60000); // 每分钟清理一次
  }

  // 生成缓存键
  private getCacheKey(url: string, params?: any): string {
    const paramsStr = params ? JSON.stringify(params) : '';
    return `${url}:${paramsStr}`;
  }

  // 设置缓存
  set<T>(url: string, data: T, ttl: number = 5 * 60 * 1000, params?: any): void {
    const key = this.getCacheKey(url, params);
    const item: CacheItem<T> = {
      data,
      timestamp: Date.now(),
      ttl,
    };

    // 存入内存缓存
    this.memoryCache.set(key, item);
    
    // 如果内存缓存过大，删除最旧的项
    if (this.memoryCache.size > this.maxMemoryItems) {
      const oldestKey = this.memoryCache.keys().next().value;
      if (oldestKey) {
        this.memoryCache.delete(oldestKey);
      }
    }

    // 同时存入 localStorage（持久化）
    this.saveToStorage(key, item);
  }

  // 获取缓存
  get<T>(url: string, params?: any): T | null {
    const key = this.getCacheKey(url, params);
    const item = this.memoryCache.get(key);

    if (!item) {
      return null;
    }

    // 检查是否过期
    if (Date.now() - item.timestamp > item.ttl) {
      this.memoryCache.delete(key);
      return null;
    }

    return item.data as T;
  }

  // 删除缓存
  delete(url: string, params?: any): void {
    const key = this.getCacheKey(url, params);
    this.memoryCache.delete(key);
    this.removeFromStorage(key);
  }

  // 清空所有缓存
  clear(): void {
    this.memoryCache.clear();
    try {
      localStorage.removeItem(this.storageKey);
    } catch (e) {
      console.warn('[Cache] Failed to clear localStorage:', e);
    }
  }

  // 清理过期缓存
  private cleanup(): void {
    const now = Date.now();
    
    // 清理内存缓存
    for (const [key, item] of this.memoryCache.entries()) {
      if (now - item.timestamp > item.ttl) {
        this.memoryCache.delete(key);
      }
    }
  }

  // 保存到 localStorage
  private saveToStorage(key: string, item: CacheItem<any>): void {
    try {
      const cacheData = JSON.parse(localStorage.getItem(this.storageKey) || '{}');
      cacheData[key] = item;
      localStorage.setItem(this.storageKey, JSON.stringify(cacheData));
    } catch (e) {
      console.warn('[Cache] Failed to save to localStorage:', e);
    }
  }

  // 从 localStorage 加载
  private loadFromStorage(): void {
    try {
      const cacheData = JSON.parse(localStorage.getItem(this.storageKey) || '{}');
      const now = Date.now();
      
      for (const [key, item] of Object.entries(cacheData)) {
        const cacheItem = item as CacheItem<any>;
        // 只加载未过期的缓存
        if (now - cacheItem.timestamp <= cacheItem.ttl) {
          this.memoryCache.set(key, cacheItem);
        }
      }
    } catch (e) {
      console.warn('[Cache] Failed to load from localStorage:', e);
    }
  }

  // 从 localStorage 删除
  private removeFromStorage(key: string): void {
    try {
      const cacheData = JSON.parse(localStorage.getItem(this.storageKey) || '{}');
      delete cacheData[key];
      localStorage.setItem(this.storageKey, JSON.stringify(cacheData));
    } catch (e) {
      console.warn('[Cache] Failed to remove from localStorage:', e);
    }
  }

  // 获取缓存统计信息
  getStats() {
    return {
      memorySize: this.memoryCache.size,
      storageSize: this.getStorageSize(),
    };
  }

  // 获取 localStorage 缓存大小
  private getStorageSize(): number {
    try {
      const cacheData = localStorage.getItem(this.storageKey);
      return cacheData ? JSON.parse(cacheData).length : 0;
    } catch {
      return 0;
    }
  }
}

// 单例导出
export const requestCache = new RequestCache();
