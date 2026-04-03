package middleware

import (
	"net/http"
	"sync"
	"time"

	"github.com/gin-gonic/gin"
)

// rateLimitEntry 限流条目
type rateLimitEntry struct {
	count     int
	resetTime time.Time
}

// rateLimiter 限流器
type rateLimiter struct {
	mu      sync.Mutex
	entries map[string]*rateLimitEntry
}

// 全局限流器实例
var globalLimiter = &rateLimiter{
	entries: make(map[string]*rateLimitEntry),
}

// cleanupOnce 确保清理协程只启动一次
var cleanupOnce sync.Once

// startCleanup 启动后台清理协程，每5分钟清理过期条目
func (r *rateLimiter) startCleanup() {
	go func() {
		ticker := time.NewTicker(5 * time.Minute)
		defer ticker.Stop()

		for range ticker.C {
			r.mu.Lock()
			now := time.Now()
			for ip, entry := range r.entries {
				if now.After(entry.resetTime) {
					delete(r.entries, ip)
				}
			}
			r.mu.Unlock()
		}
	}()
}

// RateLimitMiddleware 通用限流中间件
// maxRequests: 时间窗口内最大请求数
// window: 时间窗口
func RateLimitMiddleware(maxRequests int, window time.Duration) gin.HandlerFunc {
	// 确保清理协程只启动一次
	cleanupOnce.Do(func() {
		globalLimiter.startCleanup()
	})

	return func(c *gin.Context) {
		ip := c.ClientIP()
		now := time.Now()

		globalLimiter.mu.Lock()
		defer globalLimiter.mu.Unlock()

		entry, exists := globalLimiter.entries[ip]
		if !exists || now.After(entry.resetTime) {
			// 不存在或已过期，创建新条目
			globalLimiter.entries[ip] = &rateLimitEntry{
				count:     1,
				resetTime: now.Add(window),
			}
			c.Next()
			return
		}

		// 检查是否超限
		if entry.count >= maxRequests {
			retryAfter := int(entry.resetTime.Sub(now).Seconds())
			if retryAfter < 0 {
				retryAfter = 0
			}
			c.JSON(http.StatusTooManyRequests, gin.H{
				"error":       "too many requests",
				"retry_after": retryAfter,
			})
			c.Abort()
			return
		}

		// 增加计数
		entry.count++
		c.Next()
	}
}

// LoginRateLimit 登录专用限流中间件
// 5次/分钟/IP
func LoginRateLimit() gin.HandlerFunc {
	return RateLimitMiddleware(5, time.Minute)
}
