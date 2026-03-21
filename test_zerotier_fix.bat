@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

echo ============================================
echo   ZeroTier 权限快速修复工具
echo ============================================
echo.

REM 检查管理员权限
net session >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo ✗ 需要管理员权限！
    echo.
    echo 请右键点击此文件，选择"以管理员身份运行"
    timeout /t 10 /nobreak >nul
    exit /b 1
)

echo ✓ 管理员权限确认
echo.

REM 检查 ZeroTier 服务状态
echo 检查 ZeroTier 服务...
sc query "ZeroTierOneService" | findstr "STATE"
echo.

REM 尝试修复权限
echo 正在修复认证文件权限...
icacls "C:\ProgramData\ZeroTier\One\authtoken.secret" /grant "*S-1-5-32-545:R"
if !ERRORLEVEL! equ 0 (
    echo ✓ 权限修复成功
) else (
    echo ✗ 权限修复失败
)
echo.

REM 重启服务
echo 重启 ZeroTier 服务...
net stop "ZeroTierOneService"
timeout /t 2 /nobreak >nul
net start "ZeroTierOneService"
echo.

REM 验证连接
echo 验证 ZeroTier 连接...
"C:\Program Files (x86)\ZeroTier\One\zerotier-cli.bat" listnetworks
echo.

echo 按任意键退出...
pause >nul
