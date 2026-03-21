@echo off
REM ============================================================
REM Secure Enterprise Chat - 防火墙配置脚本
REM 配置 Windows 防火墙规则以允许外部设备访问服务
REM 必须以管理员身份运行此脚本
REM ============================================================

setlocal EnableDelayedExpansion

echo.
echo ============================================================
echo    Secure Enterprise Chat - 防火墙配置脚本
echo    目标地址: 172.25.118.254
echo ============================================================
echo.

set "GREEN=[92m"
set "RED=[91m"
set "YELLOW=[93m"
set "CYAN=[96m"
set "RESET=[0m"

REM ============================================================
REM 检查管理员权限
REM ============================================================

echo %CYAN%[步骤 1/6] 检查管理员权限...%RESET%

net session >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo.
    echo %RED%[错误] 请以管理员身份运行此脚本!%RESET%
    echo.
    echo   操作步骤:
    echo   1. 右键点击此脚本文件
    echo   2. 选择"以管理员身份运行"
    echo.
    pause
    exit /b 1
)

echo   %GREEN%[OK] 管理员权限已确认%RESET%
echo.

REM ============================================================
REM 清除旧规则
REM ============================================================

echo %CYAN%[步骤 2/6] 清除旧的防火墙规则...%RESET%

netsh advfirewall firewall delete rule name="SecChat Auth Service (TCP 8081)" >nul 2>&1
netsh advfirewall firewall delete rule name="SecChat Web Client (TCP 3000)" >nul 2>&1
netsh advfirewall firewall delete rule name="SecChat WebRTC (UDP)" >nul 2>&1
netsh advfirewall firewall delete rule name="SecChat Auth Service Outbound" >nul 2>&1
netsh advfirewall firewall delete rule name="SecChat Web Client Outbound" >nul 2>&1

echo   %GREEN%[OK] 旧规则已清除%RESET%
echo.

REM ============================================================
REM 添加入站规则
REM ============================================================

echo %CYAN%[步骤 3/6] 添加入站规则...%RESET%
echo.

REM Auth Service (TCP 8081) - 入站
echo   添加规则: Auth Service (TCP 8081) 入站...
netsh advfirewall firewall add rule ^
    name="SecChat Auth Service (TCP 8081)" ^
    dir=in ^
    action=allow ^
    protocol=TCP ^
    localport=8081 ^
    profile=any ^
    description="Secure Enterprise Chat - Auth Service API and WebSocket"

if %ERRORLEVEL% equ 0 (
    echo   %GREEN%[OK] TCP 8081 入站规则已添加%RESET%
) else (
    echo   %RED%[失败] 无法添加 TCP 8081 入站规则%RESET%
)

REM Web Client (TCP 3000) - 入站
echo   添加规则: Web Client (TCP 3000) 入站...
netsh advfirewall firewall add rule ^
    name="SecChat Web Client (TCP 3000)" ^
    dir=in ^
    action=allow ^
    protocol=TCP ^
    localport=3000 ^
    profile=any ^
    description="Secure Enterprise Chat - Web Client Development Server"

if %ERRORLEVEL% equ 0 (
    echo   %GREEN%[OK] TCP 3000 入站规则已添加%RESET%
) else (
    echo   %RED%[失败] 无法添加 TCP 3000 入站规则%RESET%
)

REM WebRTC (UDP) - 入站
echo   添加规则: WebRTC (UDP 3478, 5349) 入站...
netsh advfirewall firewall add rule ^
    name="SecChat WebRTC (UDP)" ^
    dir=in ^
    action=allow ^
    protocol=UDP ^
    localport=3478,5349 ^
    profile=any ^
    description="Secure Enterprise Chat - WebRTC STUN/TURN"

if %ERRORLEVEL% equ 0 (
    echo   %GREEN%[OK] UDP WebRTC 入站规则已添加%RESET%
) else (
    echo   %YELLOW%[警告] UDP WebRTC 规则添加失败%RESET%
)

echo.

REM ============================================================
REM 添加出站规则
REM ============================================================

echo %CYAN%[步骤 4/6] 添加出站规则...%RESET%
echo.

REM Auth Service (TCP 8081) - 出站
echo   添加规则: Auth Service (TCP 8081) 出站...
netsh advfirewall firewall add rule ^
    name="SecChat Auth Service Outbound" ^
    dir=out ^
    action=allow ^
    protocol=TCP ^
    localport=8081 ^
    profile=any ^
    description="Secure Enterprise Chat - Auth Service Outbound"

echo   %GREEN%[OK] TCP 8081 出站规则已添加%RESET%

REM Web Client (TCP 3000) - 出站
echo   添加规则: Web Client (TCP 3000) 出站...
netsh advfirewall firewall add rule ^
    name="SecChat Web Client Outbound" ^
    dir=out ^
    action=allow ^
    protocol=TCP ^
    localport=3000 ^
    profile=any ^
    description="Secure Enterprise Chat - Web Client Outbound"

echo   %GREEN%[OK] TCP 3000 出站规则已添加%RESET%

echo.

REM ============================================================
REM 验证规则
REM ============================================================

echo %CYAN%[步骤 5/6] 验证防火墙规则...%RESET%
echo.

echo   检查已添加的规则:
echo   ------------------------------------------------------------

netsh advfirewall firewall show rule name="SecChat Auth Service (TCP 8081)" >nul 2>&1
if %ERRORLEVEL% equ 0 (
    echo   %GREEN%[OK] SecChat Auth Service (TCP 8081)%RESET%
) else (
    echo   %RED%[失败] SecChat Auth Service (TCP 8081)%RESET%
)

netsh advfirewall firewall show rule name="SecChat Web Client (TCP 3000)" >nul 2>&1
if %ERRORLEVEL% equ 0 (
    echo   %GREEN%[OK] SecChat Web Client (TCP 3000)%RESET%
) else (
    echo   %RED%[失败] SecChat Web Client (TCP 3000)%RESET%
)

netsh advfirewall firewall show rule name="SecChat WebRTC (UDP)" >nul 2>&1
if %ERRORLEVEL% equ 0 (
    echo   %GREEN%[OK] SecChat WebRTC (UDP)%RESET%
) else (
    echo   %YELLOW%[警告] SecChat WebRTC (UDP)%RESET%
)

echo.

REM ============================================================
REM 显示网络信息
REM ============================================================

echo %CYAN%[步骤 6/6] 网络配置信息...%RESET%
echo.

echo   本机 IP 地址:
echo   ------------------------------------------------------------
ipconfig | findstr /i "IPv4"
echo.

echo ============================================================
echo %GREEN%   防火墙配置完成！%RESET%
echo ============================================================
echo.
echo   推荐使用的外网访问地址: %CYAN%172.25.118.254%RESET%
echo.
echo   服务访问地址:
echo   ------------------------------------------------------------
echo   API 端点:     http://172.25.118.254:8081/api/v1
echo   WebSocket:    ws://172.25.118.254:8081/api/v1/ws
echo   健康检查:     http://172.25.118.254:8081/health
echo   Web 客户端:   http://172.25.118.254:3000
echo   ------------------------------------------------------------
echo.
echo   测试命令:
echo   ------------------------------------------------------------
echo   curl http://172.25.118.254:8081/health
echo   curl http://localhost:8081/health
echo   ------------------------------------------------------------
echo.
echo   注意事项:
echo   1. 确保服务已启动后再进行测试
echo   2. 从其他设备访问时使用 172.25.118.254 地址
echo   3. 如果仍无法访问，请检查路由器防火墙设置
echo.

pause

endlocal
