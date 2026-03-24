@echo off
REM ============================================================
REM Secure Enterprise Chat - Service Startup Script
REM Starts backend API and frontend Web client
REM Target: 172.25.194.201:8081 (Backend) / :3000 (Frontend)
REM Note: Update IP if ZeroTier network address changes
REM ============================================================

setlocal EnableDelayedExpansion

echo.
echo ============================================================
echo    Secure Enterprise Chat - Service Startup Script
echo    Version: 1.0.0
echo    Date: 2026-02-22
echo ============================================================
echo.

REM Define colors
set "GREEN=[92m"
set "RED=[91m"
set "YELLOW=[93m"
set "CYAN=[96m"
set "RESET=[0m"

REM Change to script directory
set "SCRIPT_DIR=%~dp0"
cd /d "%SCRIPT_DIR%"

REM ============================================================
REM Step 1: Check Dependencies
REM ============================================================

echo %CYAN%[Step 1/6] Checking dependencies...%RESET%
echo.

REM Check Go environment
where go >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo %RED%[ERROR] Go is not installed or not in PATH%RESET%
    echo        Please visit https://golang.org/dl/ to install
    goto :error_exit
)
for /f "tokens=3" %%v in ('go version 2^>nul') do set GO_VERSION=%%v
echo   [OK] Go version: %GO_VERSION%

REM Check Node.js environment
where node >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo %RED%[ERROR] Node.js is not installed or not in PATH%RESET%
    echo        Please visit https://nodejs.org/ to install
    goto :error_exit
)
for /f "tokens=*" %%v in ('node -v 2^>nul') do set NODE_VERSION=%%v
echo   [OK] Node.js version: %NODE_VERSION%

REM Check npm environment
where npm >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo %RED%[ERROR] npm is not installed or not in PATH%RESET%
    goto :error_exit
)
for /f "tokens=*" %%v in ('npm -v 2^>nul') do set NPM_VERSION=%%v
echo   [OK] npm version: %NPM_VERSION%

echo.

REM ============================================================
REM Step 2: Check Directories and Files
REM ============================================================

echo %CYAN%[Step 2/6] Checking directories and files...%RESET%
echo.

REM Check backend service directory
if not exist "%SCRIPT_DIR%services\auth-service\cmd\main.go" (
    echo %RED%[ERROR] Backend service source not found: services\auth-service\cmd\main.go%RESET%
    goto :error_exit
)
echo   [OK] Backend service directory: services\auth-service

REM Check frontend directory
set "WEB_CLIENT_DIR=%SCRIPT_DIR%web-client"
if not exist "%WEB_CLIENT_DIR%\package.json" (
    echo %RED%[ERROR] Frontend project not found: web-client\package.json%RESET%
    goto :error_exit
)
echo   [OK] Frontend project directory: %WEB_CLIENT_DIR%

echo.

REM ============================================================
REM Step 3: Create Required Directories
REM ============================================================

echo %CYAN%[Step 3/6] Creating required directories...%RESET%
echo.

set "AUTH_SERVICE_DIR=%SCRIPT_DIR%services\auth-service"

if not exist "%AUTH_SERVICE_DIR%\data" mkdir "%AUTH_SERVICE_DIR%\data"
echo   [OK] Data directory: data

if not exist "%AUTH_SERVICE_DIR%\uploads" mkdir "%AUTH_SERVICE_DIR%\uploads"
echo   [OK] Upload directory: uploads

if not exist "%AUTH_SERVICE_DIR%\logs" mkdir "%AUTH_SERVICE_DIR%\logs"
echo   [OK] Log directory: logs

echo.

REM ============================================================
REM Step 4: Set Environment Variables
REM ============================================================

echo %CYAN%[Step 4/6] Setting environment variables...%RESET%
echo.

REM Backend service configuration
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

echo   [OK] Backend listen address: %HOST%:%PORT%
echo   [OK] Database type: SQLite
echo   [OK] Server mode: %SERVER_MODE%

echo.

REM ============================================================
REM Step 5: Check Port Availability
REM ============================================================

echo %CYAN%[Step 5/6] Checking port availability...%RESET%
echo.

REM Check port 8081
netstat -ano 2>nul | findstr /r "LISTENING" | findstr ":8081 " >nul
if %ERRORLEVEL% equ 0 (
    echo %YELLOW%[WARNING] Port 8081 is already in use%RESET%
    echo        Attempting to close existing process...
    for /f "tokens=5" %%p in ('netstat -ano 2^>nul ^| findstr /r "LISTENING" ^| findstr ":8081 "') do (
        echo        Terminating process PID: %%p
        taskkill /F /PID %%p >nul 2>&1
    )
    timeout /t 2 /nobreak >nul
    echo   [OK] Port 8081 has been released
) else (
    echo   [OK] Port 8081 is available
)

REM Check port 3000
netstat -ano 2>nul | findstr /r "LISTENING" | findstr ":3000 " >nul
if %ERRORLEVEL% equ 0 (
    echo %YELLOW%[WARNING] Port 3000 is already in use%RESET%
    echo        Attempting to close existing process...
    for /f "tokens=5" %%p in ('netstat -ano 2^>nul ^| findstr /r "LISTENING" ^| findstr ":3000 "') do (
        echo        Terminating process PID: %%p
        taskkill /F /PID %%p >nul 2>&1
    )
    timeout /t 2 /nobreak >nul
    echo   [OK] Port 3000 has been released
) else (
    echo   [OK] Port 3000 is available
)

echo.

REM ============================================================
REM Step 6: Start Services
REM ============================================================

echo %CYAN%[Step 6/6] Starting services...%RESET%
echo.

REM Create global log directory
set "LOG_DIR=%SCRIPT_DIR%logs"
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"

REM ============================================================
REM Start Backend Service
REM ============================================================

echo %GREEN%[STARTING] Backend Service (Auth Service)...%RESET%
echo        Directory: %AUTH_SERVICE_DIR%
echo        Address: http://172.25.194.201:8081 (ZeroTier Network)
echo.

cd /d "%AUTH_SERVICE_DIR%"

REM Start backend service in new window
start "SecChat Backend - 172.25.194.201:8081" cmd /k "title SecChat Backend Service && echo Starting Secure Enterprise Chat Backend... && echo. && go run cmd/main.go 2>&1"

REM Wait for backend service to start
echo        Waiting for backend service to initialize...
timeout /t 8 /nobreak >nul

REM Verify backend service health
echo        Verifying backend service health...
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
    echo   %GREEN%[OK] Backend service started successfully%RESET%
) else (
    echo   %YELLOW%[WARNING] Backend service health check timed out, please check manually%RESET%
)

echo.

REM ============================================================
REM Start Frontend Service
REM ============================================================

echo %GREEN%[STARTING] Frontend Service (Web Client)...%RESET%
echo        Directory: %WEB_CLIENT_DIR%
echo        Address: http://localhost:3000
echo        Proxy: http://172.25.194.201:8081
echo.

cd /d "%WEB_CLIENT_DIR%"

REM Check if dependencies need to be installed
if not exist "%WEB_CLIENT_DIR%\node_modules" (
    echo        Installing frontend dependencies...
    call npm install
    if %ERRORLEVEL% neq 0 (
        echo %RED%[ERROR] Frontend dependency installation failed%RESET%
        goto :error_exit
    )
)

REM Start frontend service in new window
start "SecChat Frontend - localhost:3000" cmd /k "title SecChat Web Client && echo Starting Secure Enterprise Chat Web Client... && echo. && npm run dev"

REM Wait for frontend service to start
echo        Waiting for frontend service to initialize...
timeout /t 5 /nobreak >nul

echo   %GREEN%[OK] Frontend service started%RESET%

echo.

REM ============================================================
REM Display Service Information
REM ============================================================

echo ============================================================
echo %GREEN%   All services have been started%RESET%
echo ============================================================
echo.
echo   Service Access Addresses:
echo   ------------------------------------------------------------
echo   Backend API:     http://172.25.194.201:8081/api/v1
echo   Health Check:    http://172.25.194.201:8081/health
echo   WebSocket:       ws://172.25.194.201:8081/api/v1/ws
echo   Frontend Web:    http://localhost:3000
echo   ------------------------------------------------------------
echo.
echo   Test Commands:
echo   ------------------------------------------------------------
echo   Health Check:  curl http://172.25.194.201:8081/health
echo   Public Rooms:  curl http://172.25.194.201:8081/api/v1/chat/rooms/public
echo   ------------------------------------------------------------
echo.
echo   Service Windows:
echo   - "SecChat Backend Service"  - Backend service logs
echo   - "SecChat Web Client"       - Frontend service logs
echo.
echo   Opening browser to access frontend...
echo.
pause

REM Open browser
start "" "http://localhost:3000"

echo.
echo   Tip: Closing this window will not stop services
echo         Use stop-services.bat to stop all services
echo.

goto :end

:error_exit
echo.
echo %RED%[ERROR] Service startup failed, please check error messages above%RESET%
echo.
pause
exit /b 1

:end
endlocal
