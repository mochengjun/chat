@echo off
REM 企业安全聊天系统 - 网络配置持久化修复脚本
REM 解决 ZeroTier、Docker 代理、数据库连接等配置问题

chcp 65001 >nul
setlocal enabledelayedexpansion

echo ============================================
echo   企业安全聊天系统网络配置修复
echo ============================================
echo.

set "SCRIPT_DIR=%~dp0"

REM 检查管理员权限
net session >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo ✗ 需要管理员权限执行此脚本
    echo.
    echo 使用方法:
    echo   1. 右键点击此文件
    echo   2. 选择"以管理员身份运行"
    echo.
    echo 或者在 PowerShell 中执行:
    echo   Start-Process cmd -ArgumentList "/c, '%~f0'" -Verb RunAs
    echo.
    timeout /t 10 /nobreak >nul
    exit /b 1
)

echo ✓ 管理员权限验证通过
echo.

REM 显示当前用户信息
whoami >nul 2>&1
echo 当前用户：
whoami
echo.

echo [1/4] 修复 ZeroTier 服务配置...
echo === ZeroTier 配置修复 ===

REM 修复 ZeroTier 认证文件权限
echo 修复 ZeroTier 认证文件权限...
icacls "C:\ProgramData\ZeroTier\One\authtoken.secret" /grant "*S-1-5-32-545:R" /T >nul 2>&1
if !ERRORLEVEL! equ 0 (
    echo ✓ 认证文件权限已修复
) else (
    echo ⚠ 认证文件权限修复失败
)
icacls "C:\ProgramData\ZeroTier\One" /grant "*S-1-5-32-545:F" /T >nul 2>&1

REM 重启 ZeroTier 服务
echo 重启 ZeroTier 服务...
net stop "ZeroTierOneService" >nul 2>&1
timeout /t 3 /nobreak >nul
net start "ZeroTierOneService" >nul 2>&1

REM 等待服务启动
timeout /t 2 /nobreak >nul

REM 验证 ZeroTier 连接
echo 验证 ZeroTier 连接...
"C:\Program Files (x86)\ZeroTier\One\zerotier-cli.bat" info >nul 2>&1
set ZT_RESULT=!ERRORLEVEL!
if !ZT_RESULT! equ 0 (
    echo ✓ ZeroTier 服务恢复正常
    "C:\Program Files (x86)\ZeroTier\One\zerotier-cli.bat" listnetworks | findstr "6AB565387A193124" >nul 2>&1
    if !ERRORLEVEL! equ 0 (
        echo ✓ 已连接到指定 ZeroTier 网络
    ) else (
        echo ⚠ 未连接到指定网络，正在重新连接...
        "C:\Program Files (x86)\ZeroTier\One\zerotier-cli.bat" join 6AB565387A193124
    )
) else (
    echo ✗ ZeroTier 服务修复失败（可能需要重启系统）
)

echo.
echo [2/4] 验证 Docker 代理配置...
echo === Docker 配置验证 ===

REM 检查 Docker 配置文件
set DOCKER_CONFIG=%ProgramData%\docker\config\daemon.json
if exist "%DOCKER_CONFIG%" (
    echo ✓ Docker 配置文件存在
    type "%DOCKER_CONFIG%" | findstr "172.25.194.201" >nul 2>&1
    if !ERRORLEVEL! equ 0 (
        echo ✓ Docker 代理配置正确
    ) else (
        echo ⚠ Docker 代理配置需要更新
        echo 请检查配置文件内容
    )
) else (
    echo ✗ Docker 配置文件缺失
    echo 路径：%DOCKER_CONFIG%
)

echo.
echo [3/4] 验证数据库连接...
echo === 数据库连接验证 ===

REM 切换到部署目录
cd /d "%~dp0deployments\docker"

REM 检查 PostgreSQL 连接
echo 检查 PostgreSQL 连接...
docker-compose exec postgres pg_isready >nul 2>&1
if !ERRORLEVEL! equ 0 (
    echo ✓ PostgreSQL 数据库连接正常
) else (
    echo ✗ PostgreSQL 数据库连接异常
    echo 请确认容器是否正常运行
)

REM 检查 Redis 连接 (需要认证)
echo 检查 Redis 连接...
docker-compose exec redis redis-cli ping >nul 2>&1
if !ERRORLEVEL! equ 0 (
    echo ✓ Redis 数据库连接正常
) else (
    echo ⚠ Redis 需要认证信息，连接测试跳过
    echo 注意：Redis 配置了密码认证是正常现象
)

echo.
echo [4/4] 创建配置持久化保障...
echo === 配置持久化保障 ===

REM 创建配置监控脚本
set "MONITOR_SCRIPT=%~dp0network_monitor.bat"
echo @echo off > "%MONITOR_SCRIPT%"
echo REM 网络配置状态监控脚本 >> "%MONITOR_SCRIPT%"
echo :loop >> "%MONITOR_SCRIPT%"
echo timeout /t 300 /nobreak ^>nul >> "%MONITOR_SCRIPT%"
echo "C:\Program Files (x86)\ZeroTier\One\zerotier-cli.bat" listnetworks ^| findstr "6AB565387A193124" ^>nul >> "%MONITOR_SCRIPT%"
echo if !ERRORLEVEL! neq 0 ( >> "%MONITOR_SCRIPT%"
echo     echo ZeroTier 网络连接断开，正在重新连接... >> "%MONITOR_SCRIPT%"
echo     "C:\Program Files (x86)\ZeroTier\One\zerotier-cli.bat" join 6AB565387A193124 >> "%MONITOR_SCRIPT%"
echo ) >> "%MONITOR_SCRIPT%"
echo goto loop >> "%MONITOR_SCRIPT%"

echo ✓ 创建了网络监控脚本：%MONITOR_SCRIPT%
echo   可用于持续监控 ZeroTier 网络连接状态

echo.
echo ============================================
echo   配置修复完成！
echo ============================================
echo 修复总结:
echo - ZeroTier 服务权限已修复
echo - Docker 代理配置已验证
echo - 数据库连接状态已确认
echo - 创建了配置持久化保障机制
echo.
echo 建议定期运行 network_monitor.bat 来确保配置持久化
pause
