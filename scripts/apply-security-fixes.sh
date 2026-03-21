#!/bin/bash

# 安全修复自动化脚本
# 自动应用安全审计报告中的关键修复

set -e

echo "========================================="
echo "安全修复自动化脚本"
echo "========================================="
echo ""

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 项目根目录
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# 1. 创建 .env.example 文件
echo -e "${YELLOW}[1/6] 创建环境变量模板文件...${NC}"
cat > "$PROJECT_ROOT/services/.env.example" << 'EOF'
# 数据库配置
DB_TYPE=sqlite
DATABASE_URL=postgres://user:password@localhost:5432/dbname?sslmode=disable
SQLITE_PATH=./auth.db

# JWT 配置（必须设置！）
JWT_SECRET=your-secure-jwt-secret-min-32-characters

# 服务器配置
SERVER_PORT=8081

# 媒体存储配置
MEDIA_STORAGE_PATH=./uploads/media
MEDIA_THUMBNAIL_PATH=./uploads/thumbnails
MEDIA_TEMP_PATH=./uploads/temp

# CORS 配置（生产环境必须设置！）
ALLOWED_ORIGINS=https://yourdomain.com,http://localhost:3000

# Redis 配置（可选）
REDIS_URL=redis://:password@localhost:6379/1

# FCM 推送配置（可选）
FCM_SERVER_KEY=your-fcm-server-key
FCM_PROJECT_ID=your-fcm-project-id

# MinIO 配置（可选）
MINIO_ENDPOINT=localhost:9000
MINIO_ACCESS_KEY=minioadmin
MINIO_SECRET_KEY=minioadmin123
MINIO_BUCKET=media

# 内部 API 密钥
INTERNAL_API_SECRET=your-internal-api-secret

# Admin Web 路径
ADMIN_WEB_PATH=../../admin-web
EOF

echo -e "${GREEN}✓ 已创建 .env.example${NC}"
echo ""

# 2. 创建前端环境变量模板
echo -e "${YELLOW}[2/6] 创建前端环境变量模板...${NC}"
cat > "$PROJECT_ROOT/web-client/.env.example" << 'EOF'
# API 配置
VITE_API_BASE_URL=http://localhost:8081/api/v1
VITE_WS_URL=ws://localhost:8081/api/v1/ws

# OAuth 配置
VITE_GOOGLE_CLIENT_ID=your-google-client-id.apps.googleusercontent.com

# 其他配置
VITE_APP_NAME=SecureChat
EOF

echo -e "${GREEN}✓ 已创建 web-client/.env.example${NC}"
echo ""

# 3. 创建 .gitignore 规则
echo -e "${YELLOW}[3/6] 更新 .gitignore 规则...${NC}"
if ! grep -q "\.env$" "$PROJECT_ROOT/.gitignore" 2>/dev/null; then
    cat >> "$PROJECT_ROOT/.gitignore" << 'EOF'

# 环境变量文件（包含敏感信息）
.env
.env.local
.env.production
services/.env
web-client/.env

# 日志文件
*.log
logs/

# 数据库文件
*.db
*.db-shm
*.db-wal

# 上传文件
uploads/

# 密钥文件
*.pem
*.key
EOF
    echo -e "${GREEN}✓ 已更新 .gitignore${NC}"
else
    echo -e "${YELLOW}⚠ .gitignore 已包含环境变量规则${NC}"
fi
echo ""

# 4. 创建安全头中间件模板
echo -e "${YELLOW}[4/6] 创建安全头中间件模板...${NC}"
mkdir -p "$PROJECT_ROOT/services/auth-service/internal/middleware/security"
cat > "$PROJECT_ROOT/services/auth-service/internal/middleware/security/headers.go" << 'EOF'
package security

import (
	"github.com/gin-gonic/gin"
)

// SecurityHeaders 添加安全响应头中间件
func SecurityHeaders() gin.HandlerFunc {
	return func(c *gin.Context) {
		// 防止点击劫持
		c.Header("X-Frame-Options", "DENY")
		
		// 防止 MIME 类型嗅探
		c.Header("X-Content-Type-Options", "nosniff")
		
		// XSS 保护
		c.Header("X-XSS-Protection", "1; mode=block")
		
		// 内容安全策略
		c.Header("Content-Security-Policy", "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; connect-src 'self' wss: https:")
		
		// 引用策略
		c.Header("Referrer-Policy", "strict-origin-when-cross-origin")
		
		// 权限策略
		c.Header("Permissions-Policy", "geolocation=(), microphone=(), camera=()")
		
		// HSTS (生产环境启用)
		// c.Header("Strict-Transport-Security", "max-age=31536000; includeSubDomains")
		
		c.Next()
	}
}
EOF

echo -e "${GREEN}✓ 已创建安全头中间件${NC}"
echo ""

# 5. 创建 CORS 配置模板
echo -e "${YELLOW}[5/6] 创建 CORS 配置模板...${NC}"
cat > "$PROJECT_ROOT/services/auth-service/internal/middleware/security/cors.go" << 'EOF'
package security

import (
	"os"
	"strings"

	"github.com/gin-gonic/gin"
)

// CORS 配置
type CORSConfig struct {
	AllowedOrigins   []string
	AllowedMethods   []string
	AllowedHeaders   []string
	AllowCredentials bool
	MaxAge           int
}

// DefaultCORSConfig 默认 CORS 配置
func DefaultCORSConfig() *CORSConfig {
	// 从环境变量读取允许的域名
	origins := os.Getenv("ALLOWED_ORIGINS")
	var allowedOrigins []string
	if origins != "" {
		allowedOrigins = strings.Split(origins, ",")
	} else {
		// 开发环境默认值
		allowedOrigins = []string{"http://localhost:3000", "http://localhost:5173"}
	}

	return &CORSConfig{
		AllowedOrigins: allowedOrigins,
		AllowedMethods: []string{"GET", "POST", "PUT", "DELETE", "OPTIONS", "PATCH"},
		AllowedHeaders: []string{
			"Content-Type",
			"Authorization",
			"X-Requested-With",
			"Accept",
			"Origin",
		},
		AllowCredentials: true,
		MaxAge:           86400, // 24小时
	}
}

// CORS CORS 中间件
func CORS(config *CORSConfig) gin.HandlerFunc {
	return func(c *gin.Context) {
		origin := c.GetHeader("Origin")
		
		// 检查是否在允许列表中
		allowed := false
		for _, o := range config.AllowedOrigins {
			if o == origin {
				allowed = true
				break
			}
		}

		if allowed {
			c.Header("Access-Control-Allow-Origin", origin)
			c.Header("Access-Control-Allow-Credentials", "true")
			c.Header("Access-Control-Allow-Methods", strings.Join(config.AllowedMethods, ", "))
			c.Header("Access-Control-Allow-Headers", strings.Join(config.AllowedHeaders, ", "))
			c.Header("Access-Control-Max-Age", "86400")
		}

		// 处理预检请求
		if c.Request.Method == "OPTIONS" {
			c.AbortWithStatus(204)
			return
		}

		c.Next()
	}
}
EOF

echo -e "${GREEN}✓ 已创建 CORS 配置模板${NC}"
echo ""

# 6. 创建 Rate Limiting 中间件
echo -e "${YELLOW}[6/6] 创建 Rate Limiting 中间件...${NC}"
cat > "$PROJECT_ROOT/services/auth-service/internal/middleware/security/ratelimit.go" << 'EOF'
package security

import (
	"net/http"
	"sync"
	"time"

	"github.com/gin-gonic/gin"
)

// RateLimiter 速率限制器
type RateLimiter struct {
	mu       sync.Mutex
	requests map[string][]time.Time
	limit    int           // 时间窗口内最大请求数
	window   time.Duration // 时间窗口
}

// NewRateLimiter 创建速率限制器
func NewRateLimiter(limit int, window time.Duration) *RateLimiter {
	limiter := &RateLimiter{
		requests: make(map[string][]time.Time),
		limit:    limit,
		window:   window,
	}

	// 定期清理过期记录
	go limiter.cleanupExpired()

	return limiter
}

// Allow 检查是否允许请求
func (rl *RateLimiter) Allow(key string) bool {
	rl.mu.Lock()
	defer rl.mu.Unlock()

	now := time.Now()
	windowStart := now.Add(-rl.window)

	// 获取该 key 的请求记录
	requests, exists := rl.requests[key]
	if !exists {
		rl.requests[key] = []time.Time{now}
		return true
	}

	// 过滤掉时间窗口外的请求
	var validRequests []time.Time
	for _, t := range requests {
		if t.After(windowStart) {
			validRequests = append(validRequests, t)
		}
	}

	// 检查是否超过限制
	if len(validRequests) >= rl.limit {
		rl.requests[key] = validRequests
		return false
	}

	// 添加当前请求
	validRequests = append(validRequests, now)
	rl.requests[key] = validRequests
	return true
}

// cleanupExpired 定期清理过期记录
func (rl *RateLimiter) cleanupExpired() {
	ticker := time.NewTicker(time.Minute)
	defer ticker.Stop()

	for range ticker.C {
		rl.mu.Lock()
		now := time.Now()
		windowStart := now.Add(-rl.window)

		for key, requests := range rl.requests {
			var validRequests []time.Time
			for _, t := range requests {
				if t.After(windowStart) {
					validRequests = append(validRequests, t)
				}
			}

			if len(validRequests) == 0 {
				delete(rl.requests, key)
			} else {
				rl.requests[key] = validRequests
			}
		}
		rl.mu.Unlock()
	}
}

// RateLimit 速率限制中间件
func RateLimit(limiter *RateLimiter, keyFunc func(*gin.Context) string) gin.HandlerFunc {
	return func(c *gin.Context) {
		key := keyFunc(c)
		
		if !limiter.Allow(key) {
			c.JSON(http.StatusTooManyRequests, gin.H{
				"error": "too many requests",
			})
			c.Abort()
			return
		}

		c.Next()
	}
}

// DefaultRateLimit 默认速率限制中间件（每分钟 60 次请求）
func DefaultRateLimit() gin.HandlerFunc {
	limiter := NewRateLimiter(60, time.Minute)
	
	return RateLimit(limiter, func(c *gin.Context) string {
		// 使用用户 ID 或 IP 地址作为 key
		userID, exists := c.Get("user_id")
		if exists {
			return userID.(string)
		}
		return c.ClientIP()
	})
}
EOF

echo -e "${GREEN}✓ 已创建 Rate Limiting 中间件${NC}"
echo ""

echo "========================================="
echo -e "${GREEN}✅ 安全修复模板创建完成${NC}"
echo "========================================="
echo ""
echo "下一步操作："
echo "1. 复制 .env.example 为 .env 并填写真实配置"
echo "2. 在 main.go 中导入和使用安全中间件"
echo "3. 运行测试验证修复效果"
echo ""
