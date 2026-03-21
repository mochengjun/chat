# 安全审计报告

**审计日期**: 2026-03-17  
**审计范围**: 全栈应用（Web客户端、Flutter应用、Go后端服务）  
**审计人员**: AI Security Auditor

---

## 执行摘要

本次安全审计对聊天应用进行了全面的安全性评估，涵盖认证授权、数据保护、API安全、WebSocket安全、文件上传、跨域配置等多个维度。

**总体评级**: ⚠️ **中等风险** - 存在若干需要修复的安全问题

---

## 一、依赖包安全性

### 1.1 Web 客户端

**状态**: ⚠️ 需要更新

- npm audit 需要重新生成 package-lock.json
- 发现 4 个漏洞（1 个中等，3 个高危）

**建议**:
```bash
cd web-client
npm audit fix
npm audit fix --force  # 如果需要破坏性修复
```

### 1.2 后端服务

**状态**: ✅ 良好

- Go 模块依赖通过 `go.mod` 管理
- 使用了稳定版本的依赖包

---

## 二、认证与授权安全

### 2.1 JWT Token 管理

**评级**: ✅ **良好**

**优点**:
- ✅ 使用 bcrypt 进行密码哈希（`golang.org/x/crypto/bcrypt`）
- ✅ JWT Token 包含过期时间
- ✅ 实现 Token 刷新机制
- ✅ Token 黑名单机制（登出时失效）
- ✅ 内存 + localStorage 双层存储

**问题**:
- ⚠️ JWT Secret 使用硬编码默认值 `"your-super-secret-jwt-key"`
- ⚠️ Refresh Token 存储在 localStorage，存在 XSS 攻击风险

**建议**:
```go
// main.go - 强制要求环境变量
jwtSecret := os.Getenv("JWT_SECRET")
if jwtSecret == "" {
    log.Fatal("JWT_SECRET environment variable is required")
}
```

```typescript
// 使用 HttpOnly Cookie 存储 Refresh Token
// 而不是 localStorage
```

### 2.2 OAuth 集成

**评级**: ⚠️ **需要改进**

**问题**:
- ⚠️ Google Client ID 硬编码在前端代码中
- ⚠️ 缺少 OAuth State 参数验证（防止 CSRF）

**建议**:
```typescript
// 使用环境变量
const clientId = import.meta.env.VITE_GOOGLE_CLIENT_ID;

// 添加 state 参数验证
const state = generateRandomState();
sessionStorage.setItem('oauth_state', state);
// 验证返回的 state 参数
```

### 2.3 多设备支持

**评级**: ✅ **良好**

- ✅ 支持设备 ID 标识
- ✅ 可撤销特定设备
- ✅ 设备列表管理

---

## 三、敏感数据保护

### 3.1 密码存储

**评级**: ✅ **良好**

- ✅ 使用 bcrypt 哈希（成本因子默认 10）
- ✅ 不存储明文密码
- ✅ 密码修改需验证旧密码

### 3.2 Token 存储

**评级**: ⚠️ **需要改进**

**问题**:
- ⚠️ Access Token 存储在 localStorage（XSS 风险）
- ⚠️ Refresh Token 存储在 localStorage（XSS 风险）

**建议**:
```
Access Token:
  - 存储在内存中（已实现）
  - 短期有效（已实现）
  
Refresh Token:
  - 使用 HttpOnly + Secure Cookie
  - 设置 SameSite=Strict
  - 长期有效但可撤销
```

### 3.3 日志安全

**评级**: ⚠️ **需要改进**

**问题**:
- ⚠️ 日志中可能包含敏感信息（如用户 ID、连接信息）
- ⚠️ 生产环境应移除调试日志

**建议**:
```go
// 使用日志脱敏
func maskUserID(userID string) string {
    if len(userID) <= 8 {
        return "***"
    }
    return userID[:4] + "****" + userID[len(userID)-4:]
}
```

---

## 四、API 安全性

### 4.1 输入验证

**评级**: ✅ **良好**

- ✅ 使用 Gin 框架的 `binding` 标签验证输入
- ✅ 注册时验证密码长度（min=8）
- ✅ 文件上传时验证文件类型和大小

**示例**:
```go
type RegisterRequest struct {
    Username    string  `json:"username" binding:"required,min=3,max=50"`
    Password    string  `json:"password" binding:"required,min=8"`
    Email       *string `json:"email"`
}
```

### 4.2 SQL 注入防护

**评级**: ✅ **优秀**

- ✅ 使用 GORM ORM 框架
- ✅ 自动参数化查询
- ✅ 不使用字符串拼接 SQL

### 4.3 XSS 防护

**评级**: ✅ **良好**

- ✅ React 自动转义输出（无 `dangerouslySetInnerHTML` 使用）
- ✅ 前端未发现直接插入 HTML 的代码

**建议**:
```typescript
// 可考虑添加 DOMPurify 对用户输入进行净化
import DOMPurify from 'dompurify';
const cleanContent = DOMPurify.sanitize(userInput);
```

---

## 五、WebSocket 安全性

### 5.1 认证机制

**评级**: ✅ **良好**

- ✅ WebSocket 连接需要 Token 认证
- ✅ Token 通过查询参数传递（`?token=xxx`）
- ✅ 后端验证 Token 有效性

### 5.2 连接管理

**评级**: ✅ **优秀**

- ✅ 支持多设备连接
- ✅ 用户离线宽限期（30秒）
- ✅ 自动重连机制
- ✅ 心跳保活（30秒间隔）

### 5.3 消息验证

**评级**: ⚠️ **需要改进**

**问题**:
- ⚠️ WebSocket 消息大小限制为 512KB，可能过大
- ⚠️ 缺少消息频率限制（Rate Limiting）

**建议**:
```go
// 降低消息大小限制
c.conn.SetReadLimit(64 * 1024) // 64KB

// 添加消息频率限制
type RateLimiter struct {
    mu       sync.Mutex
    messages map[string][]time.Time // userID -> timestamps
}
```

### 5.4 CORS 配置

**评级**: ❌ **严重风险**

**问题**:
```go
// websocket_handler.go:21
CheckOrigin: func(r *http.Request) bool {
    return true // 允许所有来源！
}
```

**修复**:
```go
CheckOrigin: func(r *http.Request) bool {
    origin := r.Header.Get("Origin")
    allowedOrigins := []string{
        "https://yourdomain.com",
        "http://localhost:3000",
    }
    for _, allowed := range allowedOrigins {
        if origin == allowed {
            return true
        }
    }
    return false
},
```

---

## 六、文件上传安全性

### 6.1 文件类型验证

**评级**: ⚠️ **需要改进**

**问题**:
- ⚠️ 文件类型验证依赖客户端提供的 MIME Type
- ⚠️ 缺少文件内容魔术字节验证

**建议**:
```go
// 验证文件魔术字节
func validateFileType(file multipart.File) (string, error) {
    buffer := make([]byte, 512)
    _, err := file.Read(buffer)
    if err != nil {
        return "", err
    }
    contentType := http.DetectContentType(buffer)
    file.Seek(0, 0) // 重置文件指针
    
    allowedTypes := []string{"image/jpeg", "image/png", "video/mp4"}
    for _, t := range allowedTypes {
        if contentType == t {
            return contentType, nil
        }
    }
    return "", fmt.Errorf("file type not allowed")
}
```

### 6.2 文件大小限制

**评级**: ✅ **良好**

- ✅ 分片上传支持大文件
- ✅ 单个分片大小限制

### 6.3 路径遍历防护

**评级**: ✅ **良好**

- ✅ 使用 UUID 生成文件名
- ✅ 不使用用户提供的文件名存储

---

## 七、跨域和安全头配置

### 7.1 CORS 配置

**评级**: ❌ **严重风险**

**问题**:
```go
// main.go:117
router.Use(func(c *gin.Context) {
    c.Header("Access-Control-Allow-Origin", "*") // 允许所有来源！
    c.Header("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
    c.Header("Access-Control-Allow-Headers", "Content-Type, Authorization")
    ...
})
```

**修复**:
```go
allowedOrigins := []string{
    "https://yourdomain.com",
    "http://localhost:3000",
}

router.Use(func(c *gin.Context) {
    origin := c.GetHeader("Origin")
    for _, allowed := range allowedOrigins {
        if origin == allowed {
            c.Header("Access-Control-Allow-Origin", origin)
            break
        }
    }
    c.Header("Access-Control-Allow-Credentials", "true")
    c.Header("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
    c.Header("Access-Control-Allow-Headers", "Content-Type, Authorization")
    c.Header("Access-Control-Max-Age", "86400")
    
    if c.Request.Method == "OPTIONS" {
        c.AbortWithStatus(204)
        return
    }
    c.Next()
})
```

### 7.2 安全头配置

**评级**: ⚠️ **缺失**

**建议添加**:
```go
// 添加安全响应头
router.Use(func(c *gin.Context) {
    // 防止点击劫持
    c.Header("X-Frame-Options", "DENY")
    
    // 防止 MIME 类型嗅探
    c.Header("X-Content-Type-Options", "nosniff")
    
    // XSS 保护
    c.Header("X-XSS-Protection", "1; mode=block")
    
    // 内容安全策略
    c.Header("Content-Security-Policy", "default-src 'self'")
    
    // HTTPS 强制（生产环境）
    c.Header("Strict-Transport-Security", "max-age=31536000; includeSubDomains")
    
    c.Next()
})
```

---

## 八、环境变量和配置

### 8.1 敏感信息管理

**评级**: ⚠️ **需要改进**

**问题**:
- ⚠️ 硬编码默认密码 `"synapse_password"`
- ⚠️ 硬编码默认密钥 `"your-super-secret-jwt-key"`
- ⚠️ 硬编码 Redis 密码 `"redis_password"`

**建议**:
```go
// 强制要求环境变量
func getRequiredEnv(key string) string {
    value := os.Getenv(key)
    if value == "" {
        log.Fatalf("Environment variable %s is required", key)
    }
    return value
}

jwtSecret := getRequiredEnv("JWT_SECRET")
databaseURL := getRequiredEnv("DATABASE_URL")
```

### 8.2 配置文件

**建议**:
- ✅ 创建 `.env.example` 模板
- ✅ 使用 `.gitignore` 忽略 `.env` 文件
- ✅ 生产环境使用密钥管理服务（如 AWS Secrets Manager）

---

## 九、发现的安全问题汇总

### 严重风险 (Critical) - 需立即修复

1. **CORS 配置过于宽松** (`Access-Control-Allow-Origin: *`)
   - 文件: `services/auth-service/cmd/main.go:117`
   - 影响: 允许任意来源访问 API
   - 修复: 限制为特定域名

2. **WebSocket CORS 检查禁用** (`CheckOrigin: return true`)
   - 文件: `services/auth-service/internal/handler/websocket_handler.go:21`
   - 影响: 允许任意来源建立 WebSocket 连接
   - 修复: 验证 Origin 头

### 高风险 (High) - 应尽快修复

3. **JWT Secret 硬编码默认值**
   - 文件: `services/auth-service/cmd/main.go:24`
   - 影响: 如果未设置环境变量，使用弱密钥
   - 修复: 强制要求环境变量

4. **Refresh Token 存储在 localStorage**
   - 文件: `web-client/src/core/storage/TokenStorage.ts`
   - 影响: XSS 攻击可窃取 Token
   - 修复: 使用 HttpOnly Cookie

5. **数据库密码硬编码**
   - 文件: 多个服务的 `main.go`
   - 影响: 泄露数据库凭证
   - 修复: 强制要求环境变量

### 中等风险 (Medium) - 应修复

6. **缺少消息频率限制**
   - 影响: WebSocket 消息洪泛攻击
   - 修复: 实现 Rate Limiting

7. **文件类型验证不足**
   - 影响: 可能上传恶意文件
   - 修复: 验证文件魔术字节

8. **缺少安全响应头**
   - 影响: 点击劫持、XSS 等攻击
   - 修复: 添加安全头中间件

### 低风险 (Low) - 建议修复

9. **日志未脱敏**
   - 影响: 日志泄露敏感信息
   - 修复: 日志脱敏处理

10. **OAuth State 参数缺失**
    - 影响: CSRF 攻击风险
    - 修复: 添加 State 验证

---

## 十、修复优先级和时间估算

| 优先级 | 问题 | 预计修复时间 |
|--------|------|--------------|
| P0 | CORS 配置 | 1 小时 |
| P0 | WebSocket CORS | 1 小时 |
| P0 | JWT Secret 硬编码 | 30 分钟 |
| P1 | Refresh Token 存储 | 2 小时 |
| P1 | 数据库密码硬编码 | 1 小时 |
| P2 | Rate Limiting | 3 小时 |
| P2 | 文件类型验证 | 2 小时 |
| P2 | 安全响应头 | 1 小时 |
| P3 | 日志脱敏 | 2 小时 |
| P3 | OAuth State | 1 小时 |

**总计**: 约 14.5 小时

---

## 十一、安全最佳实践建议

### 11.1 立即实施

1. ✅ 修复 CORS 配置
2. ✅ 移除所有硬编码密钥和密码
3. ✅ 添加安全响应头
4. ✅ 实现 Rate Limiting

### 11.2 短期实施（1-2周）

1. ✅ 迁移到 HttpOnly Cookie 存储
2. ✅ 实现文件内容验证
3. ✅ 添加日志脱敏
4. ✅ 完善 OAuth 流程

### 11.3 长期实施（1-3个月）

1. ✅ 实施内容安全策略 (CSP)
2. ✅ 添加 API 网关和 WAF
3. ✅ 实现密钥轮换机制
4. ✅ 定期安全审计和渗透测试
5. ✅ 实施 DevSecOps 流程

---

## 十二、合规性检查

### 12.1 GDPR 合规

- ⚠️ 需要添加隐私政策
- ⚠️ 需要实现数据导出功能
- ⚠️ 需要实现数据删除功能（Right to be Forgotten）

### 12.2 OWASP Top 10

| 风险 | 状态 | 说明 |
|------|------|------|
| A01: Broken Access Control | ⚠️ | CORS 配置问题 |
| A02: Cryptographic Failures | ✅ | 使用 bcrypt |
| A03: Injection | ✅ | 使用 ORM |
| A04: Insecure Design | ✅ | 架构合理 |
| A05: Security Misconfiguration | ⚠️ | CORS、安全头缺失 |
| A06: Vulnerable Components | ⚠️ | npm 依赖漏洞 |
| A07: Authentication Failures | ⚠️ | Token 存储方式 |
| A08: Software and Data Integrity | ✅ | 依赖版本锁定 |
| A09: Security Logging | ⚠️ | 日志需脱敏 |
| A10: SSRF | ✅ | 未发现 SSRF |

---

## 十三、总结

本次安全审计发现了若干需要立即修复的安全问题，主要集中在：

1. **CORS 配置过于宽松** - 严重风险
2. **敏感信息硬编码** - 高风险
3. **Token 存储方式不安全** - 高风险

建议按照优先级修复所有问题，并建立定期的安全审计机制。

---

**审计完成时间**: 2026-03-17  
**下次审计建议**: 3个月后或重大版本发布前
