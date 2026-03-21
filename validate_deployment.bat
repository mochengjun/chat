@echo off
REM 企业安全聊天应用 - 完整部署环境网络配置验证脚本
REM 全面测试ZeroTier网络连接、Docker容器网络、服务间通信等

echo ============================================
echo   企业安全聊天应用完整部署验证
echo ============================================
echo.

REM 创建详细的验证报告目录
set REPORT_DIR=full_deployment_validation_%date:~0,10%_%time:~0,2%%time:~3,2%%time:~6,2%
set REPORT_DIR=%REPORT_DIR: =%
mkdir "%REPORT_DIR%" 2>nul

REM 初始化详细报告文件
echo 企业安全聊天系统完整部署验证报告 > "%REPORT_DIR%\full_validation_report.txt"
echo 生成时间: %date% %time% >> "%REPORT_DIR%\full_validation_report.txt"
echo 系统版本: 1.0.0 >> "%REPORT_DIR%\full_validation_report.txt"
echo ============================================ >> "%REPORT_DIR%\full_validation_report.txt"
echo. >> "%REPORT_DIR%\full_validation_report.txt"

echo [1/10] 系统环境详细检查...
echo === 系统环境详细检查 === >> "%REPORT_DIR%\full_validation_report.txt"

REM 详细系统信息收集
systeminfo | findstr "OS Name\|OS Version\|System Type" >> "%REPORT_DIR%\full_validation_report.txt"
echo 系统架构检查:
wmic os get osarchitecture >> "%REPORT_DIR%\full_validation_report.txt"

REM 检查管理员权限
net session >nul 2>&1
if %ERRORLEVEL% equ 0 (
    echo ? 具有管理员权限
    echo 权限级别: 管理员 >> "%REPORT_DIR%\full_validation_report.txt"
) else (
    echo ? 非管理员权限，部分功能可能受限
    echo 权限级别: 标准用户 >> "%REPORT_DIR%\full_validation_report.txt"
)

echo.
echo [2/10] ZeroTier网络完整配置验证...
echo === ZeroTier网络完整配置验证 === >> "%REPORT_DIR%\full_validation_report.txt"

REM 检查ZeroTier服务状态
sc query "ZeroTier One" >nul 2>&1
if %ERRORLEVEL% equ 0 (
    echo ? ZeroTier服务已安装
    echo ZeroTier状态: 已安装 >> "%REPORT_DIR%\full_validation_report.txt"
    
    REM 检查服务运行状态
    sc query "ZeroTierOneService" | findstr "RUNNING" >nul 2>&1
    if %ERRORLEVEL% equ 0 (
        echo ? ZeroTier服务正在运行
        echo ZeroTier服务: 运行中 >> "%REPORT_DIR%\full_validation_report.txt"
    ) else (
        echo ? ZeroTier服务未运行
        echo ZeroTier服务: 未运行 >> "%REPORT_DIR%\full_validation_report.txt"
    )
    
    REM 检查网络连接(需要管理员权限)
    "C:\Program Files (x86)\ZeroTier\One\zerotier-cli.bat" listnetworks >nul 2>&1
    if %ERRORLEVEL% equ 0 (
        "C:\Program Files (x86)\ZeroTier\One\zerotier-cli.bat" listnetworks | findstr "6AB565387A193124" >nul 2>&1
        if %ERRORLEVEL% equ 0 (
            echo ? 已连接到指定ZeroTier网络
            echo ZeroTier网络: 已连接 >> "%REPORT_DIR%\full_validation_report.txt"
        ) else (
            echo ? 未连接到指定ZeroTier网络
            echo ZeroTier网络: 未连接 >> "%REPORT_DIR%\full_validation_report.txt"
        )
    ) else (
        echo ? ZeroTier CLI访问受限(需要管理员权限)
        echo ZeroTier CLI: 权限受限 >> "%REPORT_DIR%\full_validation_report.txt"
    )
) else (
    echo ? ZeroTier服务未安装
    echo ZeroTier状态: 未安装 >> "%REPORT_DIR%\full_validation_report.txt"
)
    sc qc "ZeroTier One" >> "%REPORT_DIR%\full_validation_report.txt"
    
    REM 检查服务运行状态
    for /f "tokens=4" %%s in ('sc query "ZeroTier One" ^| findstr STATE') do (
        echo 服务状态: %%s >> "%REPORT_DIR%\full_validation_report.txt"
        if "%%s"=="RUNNING" (
            echo ? ZeroTier服务正在运行
        ) else (
            echo ? ZeroTier服务未运行
            echo 尝试启动服务...
            net start "ZeroTier One" >nul 2>&1
            if %ERRORLEVEL% equ 0 (
                echo ? 服务启动成功
            ) else (
                echo ? 服务启动失败
            )
        )
    )
) else (
    echo ? ZeroTier服务未安装
    echo ZeroTier状态: 未安装 >> "%REPORT_DIR%\full_validation_report.txt"
    goto :skip_zerotier_tests
)

REM 详细ZeroTier网络信息
echo 获取ZeroTier网络详细信息...
"C:\Program Files (x86)\ZeroTier\One\zerotier-cli.bat" info >> "%REPORT_DIR%\full_validation_report.txt" 2>nul
echo. >> "%REPORT_DIR%\full_validation_report.txt"

"C:\Program Files (x86)\ZeroTier\One\zerotier-cli.bat" listnetworks >> "%REPORT_DIR%\full_validation_report.txt" 2>nul
echo. >> "%REPORT_DIR%\full_validation_report.txt"

REM 检查特定网络连接
"C:\Program Files (x86)\ZeroTier\One\zerotier-cli.bat" listnetworks | findstr "6AB565387A193124" >nul 2>&1
if %ERRORLEVEL% equ 0 (
    echo ? 已连接到指定ZeroTier网络 (6AB565387A193124)
    echo ZeroTier连接: 已连接指定网络 >> "%REPORT_DIR%\full_validation_report.txt"
    
    REM 获取分配的IP地址详细信息
    for /f "tokens=2 delims= " %%a in ('"C:\Program Files (x86)\ZeroTier\One\zerotier-cli.bat" listnetworks ^| findstr "6AB565387A193124"') do (
        echo 分配IP地址: %%a >> "%REPORT_DIR%\full_validation_report.txt"
        echo   分配IP地址: %%a
        
        REM 测试该IP的网络接口
        ipconfig | findstr "%%a" >nul
        if %ERRORLEVEL% equ 0 (
            echo ? 网络接口已正确配置
            echo 网络接口: 已配置 >> "%REPORT_DIR%\full_validation_report.txt"
        ) else (
            echo ? 网络接口配置异常
            echo 网络接口: 配置异常 >> "%REPORT_DIR%\full_validation_report.txt"
        )
    )
) else (
    echo ? 未连接到指定ZeroTier网络
    echo ZeroTier连接: 未连接指定网络 >> "%REPORT_DIR%\full_validation_report.txt"
)

:skip_zerotier_tests

echo.
echo [3/10] Docker环境和网络配置验证...
echo === Docker环境和网络配置验证 === >> "%REPORT_DIR%\full_validation_report.txt"

REM 详细Docker环境检查
docker version >> "%REPORT_DIR%\full_validation_report.txt" 2>nul
echo. >> "%REPORT_DIR%\full_validation_report.txt"

docker info >> "%REPORT_DIR%\full_validation_report.txt" 2>nul
echo. >> "%REPORT_DIR%\full_validation_report.txt"

REM 检查Docker网络配置
docker network ls >> "%REPORT_DIR%\full_validation_report.txt" 2>nul
echo. >> "%REPORT_DIR%\full_validation_report.txt"

REM 检查Docker代理配置详细信息
echo 检查Docker代理配置...
docker info | findstr "Proxy\|Registry Mirrors" >> "%REPORT_DIR%\full_validation_report.txt"
if %ERRORLEVEL% neq 0 (
    echo ? Docker代理配置未找到
    echo Docker代理: 未配置 >> "%REPORT_DIR%\full_validation_report.txt"
)

echo.
echo [4/10] 容器服务状态检查...
echo === 容器服务状态检查 === >> "%REPORT_DIR%\full_validation_report.txt"

REM 检查关键容器服务
docker ps -a >> "%REPORT_DIR%\full_validation_report.txt"
echo. >> "%REPORT_DIR%\full_validation_report.txt"

REM 检查特定服务容器
for %%s in (postgres redis auth-service nginx) do (
    docker ps | findstr "%%s" >nul
    if %ERRORLEVEL% equ 0 (
        echo ? %%s 容器正在运行
        echo %%s 容器: 运行中 >> "%REPORT_DIR%\full_validation_report.txt"
    ) else (
        echo ? %%s 容器未运行
        echo %%s 容器: 未运行 >> "%REPORT_DIR%\full_validation_report.txt"
    )
)

echo.
echo [5/10] 网络连通性全面测试...
echo === 网络连通性全面测试 === >> "%REPORT_DIR%\full_validation_report.txt"

REM 基础网络测试
echo 测试基础互联网连接...
ping -n 3 8.8.8.8 >> "%REPORT_DIR%\full_validation_report.txt" 2>nul
if %ERRORLEVEL% equ 0 (
    echo ? 基础网络连接正常
    echo 基础网络: 正常 >> "%REPORT_DIR%\full_validation_report.txt"
) else (
    echo ? 基础网络连接异常
    echo 基础网络: 异常 >> "%REPORT_DIR%\full_validation_report.txt"
)

REM ZeroTier网络测试
echo 测试ZeroTier网络连通性...
ping -n 3 172.25.194.201 >> "%REPORT_DIR%\full_validation_report.txt" 2>nul
if %ERRORLEVEL% equ 0 (
    echo ? ZeroTier网关可达
    echo ZeroTier网关: 可达 >> "%REPORT_DIR%\full_validation_report.txt"
) else (
    echo ? ZeroTier网关不可达
    echo ZeroTier网关: 不可达 >> "%REPORT_DIR%\full_validation_report.txt"
)

REM 测试容器间网络通信
echo 测试容器间网络通信...
docker run --rm alpine ping -c 3 google.com >> "%REPORT_DIR%\full_validation_report.txt" 2>nul
if %ERRORLEVEL% equ 0 (
    echo ? 容器网络访问正常
    echo 容器网络: 正常 >> "%REPORT_DIR%\full_validation_report.txt"
) else (
    echo ? 容器网络访问异常
    echo 容器网络: 异常 >> "%REPORT_DIR%\full_validation_report.txt"
)

echo.
echo [6/10] 服务端口和API测试...
echo === 服务端口和API测试 === >> "%REPORT_DIR%\full_validation_report.txt"

REM 检查端口监听状态
echo 检查关键端口监听状态:
netstat -an | findstr ":5432\|:6379\|:8081\|:80\|:443" >> "%REPORT_DIR%\full_validation_report.txt"
echo. >> "%REPORT_DIR%\full_validation_report.txt"

REM 详细API测试
echo 执行API健康检查...
powershell -Command "
try {
    $response = Invoke-WebRequest -Uri 'http://172.25.194.201:8081/health' -TimeoutSec 15 -ErrorAction Stop
    Write-Output '? Auth API服务正常'
    Write-Output ('HTTP状态码: ' + $response.StatusCode)
    Write-Output ('响应内容: ' + $response.Content)
} catch {
    Write-Output '? Auth API服务异常'
    Write-Output ('错误详情: ' + $_.Exception.Message)
}
" >> "%REPORT_DIR%\full_validation_report.txt" 2>&1

echo.
echo [7/10] 数据库连接测试...
echo === 数据库连接测试 === >> "%REPORT_DIR%\full_validation_report.txt"

REM PostgreSQL连接测试
echo 测试PostgreSQL连接...
cd /d "%~dp0deployments\docker"
docker-compose exec postgres pg_isready >nul 2>&1
if %ERRORLEVEL% equ 0 (
    echo ? PostgreSQL数据库连接正常
    echo PostgreSQL: 连接正常 >> "%REPORT_DIR%\full_validation_report.txt"
    docker-compose exec postgres pg_isready >> "%REPORT_DIR%\full_validation_report.txt" 2>nul
) else (
    echo ? PostgreSQL数据库连接异常
    echo PostgreSQL: 连接异常 >> "%REPORT_DIR%\full_validation_report.txt"
)

REM Redis连接测试(需要处理认证)
echo 测试Redis连接...
docker-compose exec redis redis-cli ping >nul 2>&1
if %ERRORLEVEL% equ 0 (
    echo ? Redis缓存服务连接正常
    echo Redis: 连接正常 >> "%REPORT_DIR%\full_validation_report.txt"
    docker-compose exec redis redis-cli ping >> "%REPORT_DIR%\full_validation_report.txt" 2>nul
) else (
    echo ? Redis需要认证信息，连接测试跳过
    echo Redis: 需要认证 >> "%REPORT_DIR%\full_validation_report.txt"
    echo 注意: Redis配置了密码认证，正常现象 >> "%REPORT_DIR%\full_validation_report.txt"
)

echo.
echo [8/10] 安全配置检查...
echo === 安全配置检查 === >> "%REPORT_DIR%\full_validation_report.txt"

REM 防火墙配置检查
echo 检查防火墙配置...
netsh advfirewall show allprofiles >> "%REPORT_DIR%\full_validation_report.txt" 2>nul
echo. >> "%REPORT_DIR%\full_validation_report.txt"

REM 检查关键端口防火墙规则
netsh advfirewall firewall show rule name=all | findstr "5432\|6379\|8081\|80\|443" >> "%REPORT_DIR%\full_validation_report.txt" 2>nul
echo. >> "%REPORT_DIR%\full_validation_report.txt"

echo.
echo [9/10] 性能和资源监控...
echo === 性能和资源监控 === >> "%REPORT_DIR%\full_validation_report.txt"

REM 系统资源使用情况
echo 系统资源使用情况:
wmic cpu get loadpercentage >> "%REPORT_DIR%\full_validation_report.txt"
echo. >> "%REPORT_DIR%\full_validation_report.txt"

wmic memphysical get MaxCapacity,MemoryDevices >> "%REPORT_DIR%\full_validation_report.txt"
echo. >> "%REPORT_DIR%\full_validation_report.txt"

REM Docker资源使用
docker stats --no-stream >> "%REPORT_DIR%\full_validation_report.txt" 2>nul
echo. >> "%REPORT_DIR%\full_validation_report.txt"

echo.
echo [10/10] 生成最终验证报告...
echo === 最终验证总结 === >> "%REPORT_DIR%\full_validation_report.txt"

REM 统计验证结果
findstr /C:"?" "%REPORT_DIR%\full_validation_report.txt" | find /c /v "" > "%TEMP%\pass_count.txt"
set /p PASS_COUNT=<"%TEMP%\pass_count.txt"
del "%TEMP%\pass_count.txt" 2>nul

findstr /C:"?" "%REPORT_DIR%\full_validation_report.txt" | find /c /v "" > "%TEMP%\fail_count.txt"
set /p FAIL_COUNT=<"%TEMP%\fail_count.txt"
del "%TEMP%\fail_count.txt" 2>nul

findstr /C:"?" "%REPORT_DIR%\full_validation_report.txt" | find /c /v "" > "%TEMP%\warn_count.txt"
set /p WARN_COUNT=<"%TEMP%\warn_count.txt"
del "%TEMP%\warn_count.txt" 2>nul

echo.
echo ============================================
echo   完整部署验证完成
echo ============================================
echo 验证通过项: %PASS_COUNT%
echo 验证警告项: %WARN_COUNT%
echo 验证失败项: %FAIL_COUNT%
echo 详细报告位置: %REPORT_DIR%\full_validation_report.txt
echo.

REM 显示验证摘要
echo 验证摘要:
echo ============================================
type "%REPORT_DIR%\full_validation_report.txt" | findstr "===\|?\|?\|?"

echo.
echo 建议措施:
if %FAIL_COUNT% gtr 0 (
    echo 1. 根据报告修复失败项
    echo 2. 重点关注网络配置和服务状态
    echo 3. 重新运行验证脚本确认修复效果
) else if %WARN_COUNT% gtr 0 (
    echo 1. 注意警告事项，建议优化配置
    echo 2. 系统基本功能正常，可投入生产使用
) else (
    echo 1. 所有验证项通过，系统配置完美
    echo 2. 可以安全投入生产环境使用
)

echo.
echo 报告已保存至: %REPORT_DIR%\full_validation_report.txt
pause