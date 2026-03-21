# 安全修复实施指南

## 一、环境变量配置

### 1. 后端服务
```bash
cd services
cp .env.example .env
# 编辑 .env 文件，设置真实配置
```

### 2. 前端应用
```bash
cd web-client
cp .env.example .env
# 编辑 .env 文件，设置真实配置
```

## 二、关键修复项

### P0 - 立即修复

#### 1. CORS 配置
- 文件: `services/auth-service/cmd/main.go`
- 修改: 将 `Allow-Origin: "*"` 改为特定域名列表
- 参考: `services/auth-service/internal/middleware/security/cors.go`

#### 2. WebSocket CORS
- 文件: `services/auth-service/internal/handler/websocket_handler.go`
- 修改: 将 `CheckOrigin: return true` 改为验证 Origin

#### 3. JWT Secret
- 文件: `services/auth-service/cmd/main.go`
- 修改: 强制要求环境变量 `JWT_SECRET`
```go
jwtSecret := os.Getenv("JWT_SECRET")
if jwtSecret == "" {
    log.Fatal("JWT_SECRET is required")
}
```

### P1 - 尽快修复

#### 4. Token 存储
- 将 Refresh Token 从 localStorage 迁移到 HttpOnly Cookie
- 设置 Cookie 属性: `HttpOnly`, `Secure`, `SameSite=Strict`

#### 5. 数据库密码

## 三、应用安全中间件

### 1. 安全响应头
```go
import "sec-chat/auth-service/internal/middleware/security"

router.Use(security.SecurityHeaders())
```

### 2. CORS 中间件
```go
corsConfig := security.DefaultCORSConfig()
router.Use(security.CORS(corsConfig))
```

### 3. Rate Limiting
```go
router.Use(security.DefaultRateLimit())
```

## 四、验证修复

### 1. 启动服务
```bash
cd services/auth-service
go run cmd/main.go
```

### 2. 测试 CORS
```bash
curl -I -X OPTIONS http://localhost:8081/api/v1/auth/login \
  -H "Origin: http://localhost:3000" \
  -H "Access-Control-Request-Method: POST"
```

### 3. 测试 Rate Limiting
```bash
for i in {1..100}; do
  curl -X POST http://localhost:8081/api/v1/auth/login
done
```

## 五、生产环境检查清单

- [ ] 所有环境变量已设置（无硬编码值)
- [ ] CORS 配置为生产域名
- [ ] 数据库密码已修改
- [ ] HTTPS 已启用
- [ ] 日志已脱敏

