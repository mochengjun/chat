@echo off
REM ============================================================
REM Secure Enterprise Chat - 服务启动脚本
REM 启动后端 API 服务和前端 Web 客户端
REM 目标地址: 172.25.118.254:8081 (后端) / :3000 (前端)
REM ============================================================

setlocal EnableDelayedExpansion

echo.
echo ============================================================
echo    Secure Enterprise Chat - 服务启动脚本
echo    版本: 1.0.0
echo    日期: 2026-02-22
echo ============================================================
echo.

REM 设置颜色
set "GREEN=[92m"
set "RED=[91m"
set "YELLOW=[93m"
set "CYAN=[96m"
set "RESET=[0m"

REM 保存脚本所在目录
set "SCRIPT_DIR=%~dp0"
cd /d "%SCRIPT_DIR%"

REM ============================================================
REM 环境检查
REM ============================================================

echo %CYAN%[步骤 1/6] 环境检查...%RESET%
echo.

REM 检查 Go 环境
where go >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo %RED%[错误] Go 未安装或未添加到 PATH%RESET%
    echo        请访问 https://golang.org/dl/ 下载安装
    goto :error_exit
)
for /f "tokens=3" %%v in ('go version 2^>nul') do set GO_VERSION=%%v
echo   [OK] Go 环境: %GO_VERSION%

REM 检查 Node.js 环境
where node >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo %RED%[错误] Node.js 未安装或未添加到 PATH%RESET%
    echo        请访问 https://nodejs.org/ 下载安装
    goto :error_exit
)
for /f "tokens=*" %%v in ('node -v 2^>nul') do set NODE_VERSION=%%v
echo   [OK] Node.js 环境: %NODE_VERSION%

REM 检查 npm 环境
where npm >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo %RED%[错误] npm 未安装或未添加到 PATH%RESET%
    goto :error_exit
)
for /f "tokens=*" %%v in ('npm -v 2^>nul') do set NPM_VERSION=%%v
echo   [OK] npm 版本: %NPM_VERSION%

echo.

REM ============================================================
REM 检查服务目录和文件
REM ============================================================

echo %CYAN%[步骤 2/6] 检查服务目录和文件...%RESET%
echo.

REM 检查后端服务目录
if not exist "%SCRIPT_DIR%services\auth-service\cmd\main.go" (
    echo %RED%[错误] 后端服务源码未找到: services\auth-service\cmd\main.go%RESET%
    goto :error_exit
)
echo   [OK] 后端服务目录: services\auth-service

REM 检查前端目录
set "WEB_CLIENT_DIR=%SCRIPT_DIR%..\web-client"
if not exist "%WEB_CLIENT_DIR%\package.json" (
    REM 尝试备选路径
    set "WEB_CLIENT_DIR=%SCRIPT_DIR%web-client"
    if not exist "!WEB_CLIENT_DIR!\package.json" (
        echo %RED%[错误] 前端项目未找到: web-client\package.json%RESET%
        goto :error_exit
    )
)
echo   [OK] 前端项目目录: %WEB_CLIENT_DIR%

echo.

REM ============================================================
REM 创建必要目录
REM ============================================================

echo %CYAN%[步骤 3/6] 创建数据目录...%RESET%
echo.

set "AUTH_SERVICE_DIR=%SCRIPT_DIR%services\auth-service"

if not exist "%AUTH_SERVICE_DIR%\data" mkdir "%AUTH_SERVICE_DIR%\data"
echo   [OK] 数据目录: data

if not exist "%AUTH_SERVICE_DIR%\uploads" mkdir "%AUTH_SERVICE_DIR%\uploads"
echo   [OK] 上传目录: uploads

if not exist "%AUTH_SERVICE_DIR%\logs" mkdir "%AUTH_SERVICE_DIR%\logs"
echo   [OK] 日志目录: logs

echo.

REM ============================================================
REM 设置环境变量
REM ============================================================

echo %CYAN%[步骤 4/6] 配置环境变量...%RESET%
echo.

REM 后端服务配置
set USE_SQLITE=true
set JWT_SECRET=SecureChatJWT2026ProductionSecretKey!@#$%%^&*
set SERVER_MODE=release
set PORT=8081
set HOST=0.0.0.0
set LOG_LEVEL=info
set LOG_FORMAT=json
set BCRYPT_COST=12
set RATE_LIMIT_REQUESTS=100
set RATE_LIMIT_WINDOW=1m
set UPLOAD_MAX_SIZE=104857600
set JWT_ACCESS_EXPIRY=1h
set JWT_REFRESH_EXPIRY=168h
set STUN_SERVER=stun:stun.l.google.com:19302

echo   [OK] 后端监听地址: %HOST%:%PORT%
echo   [OK] 数据库类型: SQLite
echo   [OK] 服务器模式: %SERVER_MODE%

echo.

REM ============================================================
REM 检查端口占用
REM ============================================================

echo %CYAN%[步骤 5/6] 检查端口占用...%RESET%
echo.

REM 检查 8081 端口
netstat -ano 2>nul | findstr /r "LISTENING" | findstr ":8081 " >nul
if %ERRORLEVEL% equ 0 (
    echo %YELLOW%[警告] 端口 8081 已被占用%RESET%
    echo        尝试关闭现有进程...
    for /f "tokens=5" %%p in ('netstat -ano 2^>nul ^| findstr /r "LISTENING" ^| findstr ":8081 "') do (
        echo        正在终止进程 PID: %%p
        taskkill /F /PID %%p >nul 2>&1
    )
    timeout /t 2 /nobreak >nul
    echo   [OK] 端口 8081 已释放
) else (
    echo   [OK] 端口 8081 可用
)

REM 检查 3000 端口
netstat -ano 2>nul | findstr /r "LISTENING" | findstr ":3000 " >nul
if %ERRORLEVEL% equ 0 (
    echo %YELLOW%[警告] 端口 3000 已被占用%RESET%
    echo        尝试关闭现有进程...
    for /f "tokens=5" %%p in ('netstat -ano 2^>nul ^| findstr /r "LISTENING" ^| findstr ":3000 "') do (
        echo        正在终止进程 PID: %%p
        taskkill /F /PID %%p >nul 2>&1
    )
    timeout /t 2 /nobreak >nul
    echo   [OK] 端口 3000 已释放
) else (
    echo   [OK] 端口 3000 可用
)

echo.

REM ============================================================
REM 启动服务
REM ============================================================

echo %CYAN%[步骤 6/6] 启动服务...%RESET%
echo.

REM 创建启动日志目录
set "LOG_DIR=%SCRIPT_DIR%logs"
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"

REM 获取当前时间戳
for /f "tokens=1-4 delims=/ " %%a in ('date /t') do set DATESTAMP=%%a%%b%%c
for /f "tokens=1-2 delims=: " %%a in ('time /t') do set TIMESTAMP=%%a%%b
set LOG_SUFFIX=%DATESTAMP%_%TIMESTAMP%

REM ============================================================
REM 启动后端服务
REM ============================================================

echo %GREEN%[启动] 后端服务 (Auth Service)...%RESET%
echo        目录: %AUTH_SERVICE_DIR%
echo        监听: http://172.25.118.254:8081
echo.

cd /d "%AUTH_SERVICE_DIR%"

REM 在新窗口中启动后端服务
start "SecChat Backend - 172.25.118.254:8081" cmd /k "title SecChat Backend Service && echo Starting Secure Enterprise Chat Backend... && echo. && go run cmd/main.go 2>&1"

REM 等待后端服务启动
echo        等待后端服务初始化...
timeout /t 8 /nobreak >nul

REM 验证后端服务健康状态
echo        验证后端服务健康状态...
set HEALTH_CHECK_PASSED=0
for /L %%i in (1,1,5) do (
    curl -s -o nul -w "%%{http_code}" http://localhost:8081/health 2>nul | findstr "200" >nul
    if !ERRORLEVEL! equ 0 (
        set HEALTH_CHECK_PASSED=1
        goto :health_check_done
    )
    timeout /t 2 /nobreak >nul
)
:health_check_done

if %HEALTH_CHECK_PASSED% equ 1 (
    echo   %GREEN%[OK] 后端服务启动成功%RESET%
) else (
    echo   %YELLOW%[警告] 后端服务健康检查超时，请检查后端窗口%RESET%
)

echo.

REM ============================================================
REM 启动前端服务
REM ============================================================

echo %GREEN%[启动] 前端服务 (Web Client)...%RESET%
echo        目录: %WEB_CLIENT_DIR%
echo        监听: http://localhost:3000
echo        代理: http://172.25.118.254:8081
echo.

cd /d "%WEB_CLIENT_DIR%"

REM 检查是否需要安装依赖
if not exist "%WEB_CLIENT_DIR%\node_modules" (
    echo        安装前端依赖...
    call npm install
    if %ERRORLEVEL% neq 0 (
        echo %RED%[错误] 前端依赖安装失败%RESET%
        goto :error_exit
    )
)

REM 在新窗口中启动前端服务
start "SecChat Frontend - localhost:3000" cmd /k "title SecChat Web Client && echo Starting Secure Enterprise Chat Web Client... && echo. && npm run dev"

REM 等待前端服务启动
echo        等待前端服务初始化...
timeout /t 5 /nobreak >nul

echo   %GREEN%[OK] 前端服务已启动%RESET%

echo.

REM ============================================================
REM 显示服务信息
REM ============================================================

echo ============================================================
echo %GREEN%   所有服务已启动！%RESET%
echo ============================================================
echo.
echo   服务访问地址:
echo   ------------------------------------------------------------
echo   后端 API:     http://172.25.118.254:8081/api/v1
echo   后端健康检查: http://172.25.118.254:8081/health
echo   WebSocket:    ws://172.25.118.254:8081/api/v1/ws
echo   前端 Web:     http://localhost:3000
echo   ------------------------------------------------------------
echo.
echo   测试命令:
echo   ------------------------------------------------------------
echo   健康检查:  curl http://172.25.118.254:8081/health
echo   公共群组:  curl http://172.25.118.254:8081/api/v1/chat/rooms/public
echo   ------------------------------------------------------------
echo.
echo   服务窗口:
echo   - "SecChat Backend Service"  - 后端服务日志
echo   - "SecChat Web Client"       - 前端服务日志
echo.
echo   按任意键打开浏览器访问前端...
echo.
pause

REM 打开浏览器
start "" "http://localhost:3000"

echo.
echo   提示: 关闭此窗口不会停止服务
echo         运行 stop-services.bat 可停止所有服务
echo.

goto :end

:error_exit
echo.
echo %RED%[错误] 服务启动失败，请检查上述错误信息%RESET%
echo.
pause
exit /b 1

:end
endlocal
