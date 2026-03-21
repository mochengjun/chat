@echo off
REM ZeroTier网络连接脚本（管理员权限）
REM 使用网络ID: 6AB565387A193124

echo === 请求管理员权限 ===
net session >nul 2>&1
if %errorLevel% == 0 (
    echo 已获得管理员权限
) else (
    echo 请以管理员身份运行此脚本
    pause
    exit /b 1
)

echo === 加入ZeroTier网络 ===
"C:\Program Files (x86)\ZeroTier\One\zerotier-cli.bat" join 6AB565387A193124

timeout /t 10 /nobreak >nul

echo === 检查网络状态 ===
"C:\Program Files (x86)\ZeroTier\One\zerotier-cli.bat" listnetworks

echo === 获取节点信息 ===
"C:\Program Files (x86)\ZeroTier\One\zerotier-cli.bat" info

echo.
echo 请在ZeroTier Central管理界面授权此节点
echo 然后重启Docker服务测试网络连接
pause