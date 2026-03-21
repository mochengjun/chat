@echo off
REM ============================================================
REM Secure Enterprise Chat - 服务停止脚本
REM 停止后端 API 服务和前端 Web 客户端
REM ============================================================

setlocal EnableDelayedExpansion

echo.
echo ============================================================
echo    Secure Enterprise Chat - 服务停止脚本
echo ============================================================
echo.

set "GREEN=[92m"
set "RED=[91m"
set "YELLOW=[93m"
set "CYAN=[96m"
set "RESET=[0m"

REM ============================================================
REM 停止后端服务 (端口 8081)
REM ============================================================

echo %CYAN%[步骤 1/3] 停止后端服务 (端口 8081)...%RESET%

set BACKEND_STOPPED=0
for /f "tokens=5" %%p in ('netstat -ano 2^>nul ^| findstr /r "LISTENING" ^| findstr ":8081 "') do (
    echo   正在终止进程 PID: %%p
    taskkill /F /PID %%p >nul 2>&1
    set BACKEND_STOPPED=1
)

if %BACKEND_STOPPED% equ 1 (
    echo   %GREEN%[OK] 后端服务已停止%RESET%
) else (
    echo   %YELLOW%[INFO] 后端服务未运行%RESET%
)

echo.

REM ============================================================
REM 停止前端服务 (端口 3000)
REM ============================================================

echo %CYAN%[步骤 2/3] 停止前端服务 (端口 3000)...%RESET%

set FRONTEND_STOPPED=0
for /f "tokens=5" %%p in ('netstat -ano 2^>nul ^| findstr /r "LISTENING" ^| findstr ":3000 "') do (
    echo   正在终止进程 PID: %%p
    taskkill /F /PID %%p >nul 2>&1
    set FRONTEND_STOPPED=1
)

if %FRONTEND_STOPPED% equ 1 (
    echo   %GREEN%[OK] 前端服务已停止%RESET%
) else (
    echo   %YELLOW%[INFO] 前端服务未运行%RESET%
)

echo.

REM ============================================================
REM 关闭服务窗口
REM ============================================================

echo %CYAN%[步骤 3/3] 关闭服务窗口...%RESET%

REM 尝试关闭服务窗口
taskkill /FI "WINDOWTITLE eq SecChat Backend*" /F >nul 2>&1
taskkill /FI "WINDOWTITLE eq SecChat Web Client*" /F >nul 2>&1
taskkill /FI "WINDOWTITLE eq SecChat Frontend*" /F >nul 2>&1

echo   %GREEN%[OK] 服务窗口已关闭%RESET%

echo.
echo ============================================================
echo %GREEN%   所有服务已停止！%RESET%
echo ============================================================
echo.

REM 验证端口已释放
echo   端口状态验证:

netstat -ano 2>nul | findstr /r "LISTENING" | findstr ":8081 " >nul
if %ERRORLEVEL% equ 0 (
    echo   %YELLOW%[警告] 端口 8081 仍被占用%RESET%
) else (
    echo   %GREEN%[OK] 端口 8081 已释放%RESET%
)

netstat -ano 2>nul | findstr /r "LISTENING" | findstr ":3000 " >nul
if %ERRORLEVEL% equ 0 (
    echo   %YELLOW%[警告] 端口 3000 仍被占用%RESET%
) else (
    echo   %GREEN%[OK] 端口 3000 已释放%RESET%
)

echo.
pause

endlocal
