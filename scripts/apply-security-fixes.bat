@echo off
chcp 65001 >nul
echo =========================================
echo 安全修复自动化脚本 (Windows)
echo =========================================
echo.

set PROJECT_ROOT=%~dp0..

echo [1/6] 创建环境变量模板文件...
(
echo # 数据库配置
echo DB_TYPE=sqlite
echo DATABASE_URL=postgres://user:password@localhost:5432/dbname?sslmode=disable
echo SQLITE_PATH=./auth.db
echo.
echo # JWT 配置（必须设置！）
echo JWT_SECRET=your-secure-jwt-secret-min-32-characters
echo.
echo # 服务器配置
echo SERVER_PORT=8081
echo.
echo # 媒体存储配置
echo MEDIA_STORAGE_PATH=./uploads/media
echo MEDIA_THUMBNAIL_PATH=./uploads/thumbnails
echo MEDIA_TEMP_PATH=./uploads/temp
echo.
echo # CORS 配置（生产环境必须设置！）
echo ALLOWED_ORIGINS=https://yourdomain.com,http://localhost:3000
echo.
echo # Redis 配置（可选）
echo REDIS_URL=redis://:password@localhost:6379/1
echo.
echo # FCM 推送配置（可选）
echo FCM_SERVER_KEY=your-fcm-server-key
echo FCM_PROJECT_ID=your-fcm-project-id
echo.
echo # MinIO 配置（可选）
echo MINIO_ENDPOINT=localhost:9000
echo MINIO_ACCESS_KEY=minioadmin
echo MINIO_SECRET_KEY=minioadmin123
echo MINIO_BUCKET=media
echo.
echo # 内部 API 密钥
echo INTERNAL_API_SECRET=your-internal-api-secret
) > "%PROJECT_ROOT%\services\.env.example"
echo ✓ 已创建 services\.env.example
echo.

echo [2/6] 创建前端环境变量模板...
(
echo # API 配置
echo VITE_API_BASE_URL=http://localhost:8081/api/v1
echo VITE_WS_URL=ws://localhost:8081/api/v1/ws
echo.
echo # OAuth 配置
echo VITE_GOOGLE_CLIENT_ID=your-google-client-id.apps.googleusercontent.com
echo.
echo # 其他配置
echo VITE_APP_NAME=SecureChat
) > "%PROJECT_ROOT%\web-client\.env.example"
echo ✓ 已创建 web-client\.env.example
echo.

echo [3/6] 更新 .gitignore 规则...
if not exist "%PROJECT_ROOT%\.gitignore" (
    echo # 环境变量（包含敏感信息） > "%PROJECT_ROOT%\.gitignore"
    echo .env >> "%PROJECT_ROOT%\.gitignore"
    echo .env.local >> "%PROJECT_ROOT%\.gitignore"
    echo .env.production >> "%PROJECT_ROOT%\.gitignore"
    echo. >> "%PROJECT_ROOT%\.gitignore"
    echo # 日志文件 >> "%PROJECT_ROOT%\.gitignore"
    echo logs/ >> "%PROJECT_ROOT%\.gitignore"
    echo *.log >> "%PROJECT_ROOT%\.gitignore"
    echo. >> "%PROJECT_ROOT%\.gitignore"
    echo # 数据库文件 >> "%PROJECT_ROOT%\.gitignore"
    echo *.db >> "%PROJECT_ROOT%\.gitignore"
    echo *.db-shm >> "%PROJECT_ROOT%\.gitignore"
    echo *.db-wal >> "%PROJECT_ROOT%\.gitignore"
    echo. >> "%PROJECT_ROOT%\.gitignore"
    echo # 上传文件 >> "%PROJECT_ROOT%\.gitignore"
    echo uploads/ >> "%PROJECT_ROOT%\.gitignore"
    echo.
    echo ✓ 已创建 .gitignore
) else (
    echo ! .gitignore 已存在，跳过
)
echo.

echo [4/6] 创建安全修复说明文档...
(
echo # 安全修复实施指南
echo.
echo ## 一、环境变量配置
echo.
echo ### 1. 后端服务
echo ```bash
echo cd services
echo cp .env.example .env
echo # 编辑 .env 文件，设置真实配置
echo ```
echo.
echo ### 2. 前端应用
echo ```bash
echo cd web-client
echo cp .env.example .env
echo # 编辑 .env 文件，设置真实配置
echo ```
echo.
echo ## 二、关键修复项
echo.
echo ### P0 - 立即修复
echo.
echo #### 1. CORS 配置
echo - 文件: `services/auth-service/cmd/main.go`
echo - 修改: 将 `Allow-Origin: "*"` 改为特定域名列表
echo - 参考: `services/auth-service/internal/middleware/security/cors.go`
echo.
echo #### 2. WebSocket CORS
echo - 文件: `services/auth-service/internal/handler/websocket_handler.go`
echo - 修改: 将 `CheckOrigin: return true` 改为验证 Origin
echo.
echo #### 3. JWT Secret
echo - 文件: `services/auth-service/cmd/main.go`
echo - 修改: 强制要求环境变量 `JWT_SECRET`
echo ```go
echo jwtSecret := os.Getenv("JWT_SECRET"^)
echo if jwtSecret == "" {
echo     log.Fatal("JWT_SECRET is required"^)
echo }
echo ```
echo.
echo ### P1 - 尽快修复
echo.
echo #### 4. Token 存储
echo - 将 Refresh Token 从 localStorage 迁移到 HttpOnly Cookie
echo - 设置 Cookie 属性: `HttpOnly`, `Secure`, `SameSite=Strict`
echo.
echo #### 5. 数据库密码
echo - 移除所有硬编码的默认密码
echo - 使用环境变量: `DATABASE_URL`
echo.
echo ## 三、应用安全中间件
echo.
echo ### 1. 安全响应头
echo ```go
echo import "sec-chat/auth-service/internal/middleware/security"
echo.
echo router.Use(security.SecurityHeaders(^)^)
echo ```
echo.
echo ### 2. CORS 中间件
echo ```go
echo corsConfig := security.DefaultCORSConfig(^)
echo router.Use(security.CORS(corsConfig^)^)
echo ```
echo.
echo ### 3. Rate Limiting
echo ```go
echo router.Use(security.DefaultRateLimit(^)^)
echo ```
echo.
echo ## 四、验证修复
echo.
echo ### 1. 启动服务
echo ```bash
echo cd services/auth-service
echo go run cmd/main.go
echo ```
echo.
echo ### 2. 测试 CORS
echo ```bash
echo curl -I -X OPTIONS http://localhost:8081/api/v1/auth/login \
echo   -H "Origin: http://localhost:3000" \
echo   -H "Access-Control-Request-Method: POST"
echo ```
echo.
echo ### 3. 测试 Rate Limiting
echo ```bash
echo for i in {1..100}; do
echo   curl -X POST http://localhost:8081/api/v1/auth/login
echo done
echo ```
echo.
echo ## 五、生产环境检查清单
echo.
echo - [ ] 所有环境变量已设置（无硬编码值^)
echo - [ ] CORS 配置为生产域名
echo - [ ] JWT Secret 强度足够（32+ 字符^)
echo - [ ] 数据库密码已修改
echo - [ ] HTTPS 已启用
echo - [ ] 安全响应头已添加
echo - [ ] Rate Limiting 已启用
echo - [ ] 日志已脱敏
echo - [ ] 备份机制已建立
echo.
) > "%PROJECT_ROOT%\docs\SECURITY_FIX_GUIDE.md"
echo ✓ 已创建安全修复指南
echo.

echo [5/6] 创建安全检查脚本...
(
echo @echo off
echo echo =========================================
echo echo 安全配置检查
echo echo =========================================
echo echo.
echo.
echo echo [1] 检查环境变量文件...
echo if exist "%PROJECT_ROOT%\services\.env" (
echo     echo ✓ services\.env 存在
echo ) else (
echo     echo ✗ services\.env 不存在
echo )
echo.
echo if exist "%PROJECT_ROOT%\web-client\.env" (
echo     echo ✓ web-client\.env 存在
echo ) else (
echo     echo ✗ web-client\.env 不存在
echo )
echo echo.
echo.
echo echo [2] 检查硬编码密钥...
echo findstr /S /I "your-super-secret" "%PROJECT_ROOT%\services\*.go" >nul 2>&1
echo if %%errorlevel%% equ 0 (
echo     echo ✗ 发现硬编码的 JWT Secret
echo ) else (
echo     echo ✓ 未发现硬编码的 JWT Secret
echo )
echo.
echo findstr /S /I "synapse_password" "%PROJECT_ROOT%\services\*.go" >nul 2>&1
echo if %%errorlevel%% equ 0 (
echo     echo ✗ 发现硬编码的数据库密码
echo ) else (
echo     echo ✓ 未发现硬编码的数据库密码
echo )
echo echo.
echo.
echo echo [3] 检查 CORS 配置...
echo findstr /S /I "Access-Control-Allow-Origin.*\*" "%PROJECT_ROOT%\services\*.go" >nul 2>&1
echo if %%errorlevel%% equ 0 (
echo     echo ✗ CORS 配置过于宽松
echo ) else (
echo     echo ✓ CORS 配置已限制
echo )
echo echo.
echo.
echo echo =========================================
echo echo 检查完成
echo echo =========================================
) > "%PROJECT_ROOT%\scripts\check-security.bat"
echo ✓ 已创建安全检查脚本
echo.

echo [6/6] 创建 .gitignore 补充规则...
(
echo.
echo # 安全相关
echo .env
echo .env.local
echo .env.production
echo services/.env
echo web-client/.env
echo.
echo # 密钥文件
echo *.pem
echo *.key
echo *.crt
echo.
echo # 日志
echo logs/
echo *.log
) >> "%PROJECT_ROOT%\.gitignore"
echo ✓ 已更新 .gitignore
echo.

echo =========================================
echo ✓ 安全修复模板创建完成
echo =========================================
echo.
echo 下一步操作：
echo 1. 复制 .env.example 为 .env 并填写真实配置
echo 2. 运行 check-security.bat 检查安全配置
echo 3. 查看 docs\SECURITY_FIX_GUIDE.md 了解详细修复步骤
echo 4. 运行 npm audit fix 修复依赖漏洞
echo.
pause
