@echo off
REM ============================================================
REM Secure Enterprise Chat - 服务状态检查脚本
REM 检查后端和前端服务的运行状态
REM ============================================================

setlocal EnableDelayedExpansion

echo.
echo ============================================================
echo    Secure Enterprise Chat - 服务状态检查
echo ============================================================
echo.

set "GREEN=[92m"
set "RED=[91m"
set "YELLOW=[93m"
set "CYAN=[96m"
set "RESET=[0m"

REM ============================================================
REM 检查端口状态
REM ============================================================

echo %CYAN%[端口状态]%RESET%
echo.

REM 检查 8081 端口
netstat -ano 2>nul | findstr ":8081" | findstr "LISTENING" >nul
if %ERRORLEVEL% equ 0 (
    echo   %GREEN%[运行中] 后端服务 (端口 8081)%RESET%
    set BACKEND_RUNNING=1
) else (
    echo   %RED%[未运行] 后端服务 (端口 8081)%RESET%
    set BACKEND_RUNNING=0
)

REM 检查 3000 端口
netstat -ano 2>nul | findstr ":3000" | findstr "LISTENING" >nul
if %ERRORLEVEL% equ 0 (
    echo   %GREEN%[运行中] 前端服务 (端口 3000)%RESET%
    set FRONTEND_RUNNING=1
) else (
    echo   %RED%[未运行] 前端服务 (端口 3000)%RESET%
    set FRONTEND_RUNNING=0
)

echo.

REM ============================================================
REM 健康检查
REM ============================================================

echo %CYAN%[健康检查]%RESET%
echo.

if %BACKEND_RUNNING% equ 1 (
    echo   检查后端 API 健康状态...
    curl -s http://localhost:8081/health > "%TEMP%\health_check.tmp" 2>nul
    if %ERRORLEVEL% equ 0 (
        type "%TEMP%\health_check.tmp" | findstr "ok" >nul
        if !ERRORLEVEL! equ 0 (
            echo   %GREEN%[健康] 后端 API 响应正常%RESET%
            echo   响应: 
            type "%TEMP%\health_check.tmp"
            echo.
        ) else (
            echo   %YELLOW%[警告] 后端 API 响应异常%RESET%
        )
        del "%TEMP%\health_check.tmp" 2>nul
    ) else (
        echo   %RED%[错误] 无法连接到后端 API%RESET%
    )
) else (
    echo   %YELLOW%[跳过] 后端服务未运行，跳过健康检查%RESET%
)

echo.

REM ============================================================
REM 显示访问地址
REM ============================================================

echo %CYAN%[访问地址]%RESET%
echo.
echo   本地访问:
echo   ------------------------------------------------------------
echo   后端 API:     http://localhost:8081/api/v1
echo   健康检查:     http://localhost:8081/health
echo   WebSocket:    ws://localhost:8081/api/v1/ws
echo   前端 Web:     http://localhost:3000
echo.
echo   外网访问 (172.25.118.254):
echo   ------------------------------------------------------------
echo   后端 API:     http://172.25.118.254:8081/api/v1
echo   健康检查:     http://172.25.118.254:8081/health
echo   WebSocket:    ws://172.25.118.254:8081/api/v1/ws
echo   前端 Web:     http://172.25.118.254:3000
echo.

REM ============================================================
REM 显示进程详情
REM ============================================================

echo %CYAN%[进程详情]%RESET%
echo.

if %BACKEND_RUNNING% equ 1 (
    echo   后端服务进程:
    for /f "tokens=5" %%p in ('netstat -ano 2^>nul ^| findstr ":8081" ^| findstr "LISTENING"') do (
        echo   PID: %%p
        tasklist /FI "PID eq %%p" /FO TABLE /NH 2>nul | findstr /v "INFO"
    )
    echo.
)

if %FRONTEND_RUNNING% equ 1 (
    echo   前端服务进程:
    for /f "tokens=5" %%p in ('netstat -ano 2^>nul ^| findstr ":3000" ^| findstr "LISTENING"') do (
        echo   PID: %%p
        tasklist /FI "PID eq %%p" /FO TABLE /NH 2>nul | findstr /v "INFO"
    )
    echo.
)

echo ============================================================
echo %GREEN%   状态检查完成！%RESET%
echo ============================================================
echo.

if %BACKEND_RUNNING% equ 0 (
    echo   %YELLOW%提示: 后端服务未运行，请运行 start-services.bat 启动服务%RESET%
)

if %FRONTEND_RUNNING% equ 0 (
    echo   %YELLOW%提示: 前端服务未运行，请运行 start-services.bat 启动服务%RESET%
)

echo.
pause

endlocal
