# 安全审计 - 需要人工确认的关键事项

**审计日期**: 2026-03-17  
**状态**: 等待用户确认和执行

---

## 📋 需要您确认和执行的关键操作

### 🔴 P0 - 立即执行（必须完成才能部署生产环境）

#### 1. 配置环境变量 ⚠️ **必须操作**

**步骤**:
```bash
# 1. 复制环境变量模板
cd c:\Users\HZHF\source\chat\services
copy .env.example .env

# 2. 编辑 .env 文件，设置以下关键配置：
```

**必须设置的变量**:
```env
# JWT 密钥（必须32+字符）
JWT_SECRET=<请设置一个强密钥，例如：your-super-secret-jwt-key-at-least-32-chars>

# 数据库连接（请修改密码）
DATABASE_URL=postgres://synapse:<请设置密码>@localhost:5432/synapse?sslmode=disable

# CORS 允许的域名（生产环境必须设置）
ALLOWED_ORIGINS=https://yourdomain.com,http://localhost:3000

# 内部 API 密钥
INTERNAL_API_SECRET=<请设置一个强密钥>
```

**确认**: 
- [ ] 我已复制 `.env.example` 为 `.env`
- [ ] 我已设置强密钥的 `JWT_SECRET`
- [ ] 我已修改数据库密码
- [ ] 我已设置 `ALLOWED_ORIGINS`（生产域名列表）

---

#### 2. 修复 CORS 配置 ⚠️ **必须操作**

**当前问题**: 允许所有来源访问 API（安全风险）

**需要修改的文件**: `services/auth-service/cmd/main.go`

**当前代码** (第117行):
```go
router.Use(func(c *gin.Context) {
    c.Header("Access-Control-Allow-Origin", "*")  // ❌ 不安全
    ...
})
```

**修复方案 A - 使用环境变量（推荐）**:
```go
// 1. 在文件开头添加读取环境变量
allowedOriginsStr := getEnv("ALLOWED_ORIGINS", "http://localhost:3000")
allowedOrigins := strings.Split(allowedOriginsStr, ",")

// 2. 替换 CORS 中间件
router.Use(func(c *gin.Context) {
    origin := c.GetHeader("Origin")
    for _, allowed := range allowedOrigins {
        if origin == allowed {
            c.Header("Access-Control-Allow-Origin", origin)
            c.Header("Access-Control-Allow-Credentials", "true")
            c.Header("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
            c.Header("Access-Control-Allow-Headers", "Content-Type, Authorization")
            c.Header("Access-Control-Max-Age", "86400")
            break
        }
    }
    
    if c.Request.Method == "OPTIONS" {
        c.AbortWithStatus(204)
        return
    }
    c.Next()
})
```

**修复方案 B - 使用安全中间件（推荐用于大型项目）**:
```go
// 已为您创建好的中间件文件:
// services/auth-service/internal/middleware/security/cors.go

// 在 main.go 中使用:
import "sec-chat/auth-service/internal/middleware/security"

func main() {
    router := gin.Default()
    
    // 使用 CORS 中间件
    corsConfig := security.DefaultCORSConfig()
    router.Use(security.CORS(corsConfig))
    
    // ... 其他代码
}
```

**确认**:
- [ ] 我已选择修复方案 (A 或 B)
- [ ] 我已修改 CORS 配置
- [ ] 我已在 .env 中设置 ALLOWED_ORIGINS

---

#### 3. 修复 WebSocket CORS ⚠️ **必须操作**

**当前问题**: WebSocket 允许任意来源连接

**需要修改的文件**: `services/auth-service/internal/handler/websocket_handler.go`

**当前代码** (第17-23行):
```go
var upgrader = websocket.Upgrader{
    ReadBufferSize:  1024,
    WriteBufferSize: 1024,
    CheckOrigin: func(r *http.Request) bool {
        return true  // ❌ 不安全：允许所有来源
    },
}
```

**修复方案**:
```go
var upgrader = websocket.Upgrader{
    ReadBufferSize:  1024,
    WriteBufferSize: 1024,
    CheckOrigin: func(r *http.Request) bool {
        origin := r.Header.Get("Origin")
        // 从环境变量读取允许的域名
        allowedOriginsStr := os.Getenv("ALLOWED_ORIGINS")
        if allowedOriginsStr == "" {
            allowedOriginsStr = "http://localhost:3000"
        }
        allowedOrigins := strings.Split(allowedOriginsStr, ",")
        
        for _, allowed := range allowedOrigins {
            if origin == allowed {
                return true
            }
        }
        return false
    },
}
```

**确认**:
- [ ] 我已修改 WebSocket CORS 配置

---

#### 4. 强制要求 JWT Secret ⚠️ **必须操作**

**当前问题**: 如果未设置环境变量，使用弱默认密钥

**需要修改的文件**: `services/auth-service/cmd/main.go`

**当前代码** (第24行):
```go
jwtSecret := getEnv("JWT_SECRET", "your-super-secret-jwt-key")  // ❌ 有默认值
```

**修复方案**:
```go
jwtSecret := os.Getenv("JWT_SECRET")
if jwtSecret == "" {
    log.Fatal("JWT_SECRET environment variable is required. Please set it in .env file.")
}
if len(jwtSecret) < 32 {
    log.Fatal("JWT_SECRET must be at least 32 characters long")
}
```

**确认**:
- [ ] 我已修改 JWT Secret 验证逻辑
- [ ] 我已在 .env 中设置强密钥（32+字符）

---

### 🟠 P1 - 尽快执行（生产环境部署前完成）

#### 5. 前端环境变量配置

**步骤**:
```bash
cd c:\Users\HZHF\source\chat\web-client
copy .env.example .env
```

**必须设置**:
```env
# Google OAuth 客户端 ID（从 Google Cloud Console 获取）
VITE_GOOGLE_CLIENT_ID=<your-client-id>.apps.googleusercontent.com
```

**确认**:
- [ ] 我已创建 web-client/.env
- [ ] 我已在 Google Cloud Console 创建 OAuth 凭据
- [ ] 我已设置 VITE_GOOGLE_CLIENT_ID

---

#### 6. 修复依赖包漏洞

**当前问题**: npm audit 显示 4 个漏洞

**执行**:
```bash
cd c:\Users\HZHF\source\chat\web-client
npm audit fix
npm audit fix --force  # 如果需要破坏性修复
```

**确认**:
- [ ] 我已运行 npm audit fix
- [ ] 我已确认漏洞数量减少或修复

---

### 🟡 P2 - 建议执行（提升安全性）

#### 7. 添加安全响应头（可选但推荐）

**方案 A - 手动添加**:
在 `services/auth-service/cmd/main.go` 中添加:
```go
router.Use(func(c *gin.Context) {
    c.Header("X-Frame-Options", "DENY")
    c.Header("X-Content-Type-Options", "nosniff")
    c.Header("X-XSS-Protection", "1; mode=block")
    c.Header("Content-Security-Policy", "default-src 'self'")
    c.Next()
})
```

**方案 B - 使用安全中间件（推荐）**:
```go
import "sec-chat/auth-service/internal/middleware/security"

router.Use(security.SecurityHeaders())
```

**确认**:
- [ ] 我已添加安全响应头

---

#### 8. 启用 Rate Limiting（可选但推荐）

**防止 DDoS 和暴力破解**

**使用方法**:
```go
import "sec-chat/auth-service/internal/middleware/security"

// 全局 Rate Limiting
router.Use(security.DefaultRateLimit())

// 或者针对登录接口单独限制
auth.POST("/login", security.DefaultRateLimit(), authHandler.Login)
```

**确认**:
- [ ] 我已启用 Rate Limiting

---

## 📊 完成进度追踪

### 必须完成（P0）
- [ ] 配置环境变量
- [ ] 修复 CORS 配置
- [ ] 修复 WebSocket CORS
- [ ] 强制要求 JWT Secret

### 应该完成（P1）
- [ ] 前端环境变量配置
- [ ] 修复依赖包漏洞

### 建议完成（P2）
- [ ] 添加安全响应头
- [ ] 启用 Rate Limiting

---

## 🚀 部署前最终检查清单

在部署到生产环境前，请确认：

### 环境配置
- [ ] 所有 `.env` 文件已创建并配置
- [ ] JWT_SECRET 已设置（32+ 字符）
- [ ] DATABASE_URL 密码已修改
- [ ] ALLOWED_ORIGINS 已设置为生产域名
- [ ] Google OAuth 凭据已配置

### 代码修改
- [ ] CORS 配置已限制为特定域名
- [ ] WebSocket CORS 已验证 Origin
- [ ] JWT Secret 强制验证已添加
- [ ] 硬编码密码已移除

### 安全措施
- [ ] HTTPS 已启用
- [ ] 安全响应头已添加
- [ ] Rate Limiting 已启用
- [ ] 依赖漏洞已修复

### 测试验证
- [ ] 本地测试通过
- [ ] 安全配置验证脚本通过
- [ ] 渗透测试完成（可选）

---

## 📞 需要帮助？

如果在执行以上步骤时遇到问题：

1. 查看详细文档：
   - `docs/SECURITY_AUDIT_REPORT.md` - 完整审计报告
   - `docs/SECURITY_FIX_GUIDE.md` - 详细修复指南

2. 使用安全检查脚本：
   ```bash
   # Windows
   c:\Users\HZHF\source\chat\scripts\check-security.bat
   ```

3. 常见问题：
   - **Q: 如何生成强密钥？**
     ```bash
     # Linux/macOS
     openssl rand -base64 32
     
     # Windows PowerShell
     [Convert]::ToBase64String((1..32 | ForEach-Object { Get-Random -Maximum 256 }))
     ```
   
   - **Q: Google OAuth 凭据在哪里获取？**
     访问: https://console.cloud.google.com/apis/credentials

---

## ✅ 确认完成

完成所有必须项后，请确认：

**我已完成所有 P0 优先级的安全修复，应用已准备好进行下一步测试。**

签名: ________________  
日期: ________________

---

**重要提示**: 未完成 P0 优先级修复前，请勿将应用部署到生产环境！
