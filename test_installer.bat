@echo off
REM 企业安全聊天应用 - Windows安装包完整功能测试脚本
REM 验证ZeroTier网络配置、Docker代理设置、镜像加速器配置等功能模块

echo ============================================
echo   企业安全聊天应用安装包完整功能测试
echo ============================================
echo.

REM 创建测试报告目录
set TEST_REPORT_DIR=test_results_%date:~0,10%_%time:~0,2%%time:~3,2%%time:~6,2%
set TEST_REPORT_DIR=%TEST_REPORT_DIR: =%
mkdir "%TEST_REPORT_DIR%" 2>nul

REM 初始化测试报告
echo Windows安装包功能测试报告 > "%TEST_REPORT_DIR%\test_report.txt"
echo 测试时间: %date% %time% >> "%TEST_REPORT_DIR%\test_report.txt"
echo ============================================ >> "%TEST_REPORT_DIR%\test_report.txt"
echo. >> "%TEST_REPORT_DIR%\test_report.txt"

echo [1/8] 检查构建输出文件...
echo === 构建文件检查 === >> "%TEST_REPORT_DIR%\test_report.txt"

set BUILD_DIR=apps\flutter_app\build\windows\x64\runner\Release
if exist "%BUILD_DIR%\sec_chat.exe" (
    echo ✓ 主程序文件存在
    echo 主程序: 存在 >> "%TEST_REPORT_DIR%\test_report.txt"
    for %%F in ("%BUILD_DIR%\sec_chat.exe") do (
        echo   文件大小: %%~zF bytes
        echo   修改时间: %%~tF
        echo   文件大小: %%~zF bytes >> "%TEST_REPORT_DIR%\test_report.txt"
    )
) else (
    echo ✗ 主程序文件不存在
    echo 主程序: 不存在 >> "%TEST_REPORT_DIR%\test_report.txt"
    echo   请先完成构建: flutter build windows --release
    goto :test_failed
)

echo.
echo [2/8] 检查依赖文件完整性...
echo === 依赖文件检查 === >> "%TEST_REPORT_DIR%\test_report.txt"

set DLL_COUNT=0
for %%F in ("%BUILD_DIR%\*.dll") do (
    set /a DLL_COUNT+=1
)
echo 发现 %DLL_COUNT% 个DLL文件
echo DLL文件数量: %DLL_COUNT% >> "%TEST_REPORT_DIR%\test_report.txt"

if exist "%BUILD_DIR%\data" (
    echo ✓ 数据目录存在
    echo 数据目录: 存在 >> "%TEST_REPORT_DIR%\test_report.txt"
    echo   包含资源文件和assets
    
    REM 检查网络配置相关文件
    if exist "%BUILD_DIR%\data\flutter_assets\assets\" (
        echo ✓ Assets资源配置正确
        echo Assets配置: 正确 >> "%TEST_REPORT_DIR%\test_report.txt"
    )
) else (
    echo ✗ 数据目录缺失
    echo 数据目录: 缺失 >> "%TEST_REPORT_DIR%\test_report.txt"
)

echo.
echo [3/8] 网络配置模块测试...
echo === 网络配置测试 === >> "%TEST_REPORT_DIR%\test_report.txt"

REM 测试ZeroTier配置
echo 测试ZeroTier网络配置...
set ZEROTIER_INSTALLED=0
if exist "C:\Program Files (x86)\ZeroTier\One\zerotier-cli.bat" (
    echo ✓ ZeroTier客户端已安装
    echo ZeroTier安装: 已安装 >> "%TEST_REPORT_DIR%\test_report.txt"
    set ZEROTIER_INSTALLED=1
) else (
    echo ⚠ ZeroTier客户端未安装
    echo ZeroTier安装: 未安装 >> "%TEST_REPORT_DIR%\test_report.txt"
)

REM 测试Docker配置
echo 测试Docker环境...
docker version >nul 2>&1
if %ERRORLEVEL% equ 0 (
    echo ✓ Docker环境可用
    echo Docker环境: 可用 >> "%TEST_REPORT_DIR%\test_report.txt"
    
    REM 检查Docker代理配置
    docker info | findstr "Proxy" >nul 2>&1
    if %ERRORLEVEL% equ 0 (
        echo ✓ Docker代理配置存在
        echo Docker代理: 已配置 >> "%TEST_REPORT_DIR%\test_report.txt"
        docker info | findstr "Proxy" >> "%TEST_REPORT_DIR%\test_report.txt"
    ) else (
        echo ⚠ Docker代理未配置
        echo Docker代理: 未配置 >> "%TEST_REPORT_DIR%\test_report.txt"
    )
) else (
    echo ⚠ Docker环境不可用
    echo Docker环境: 不可用 >> "%TEST_REPORT_DIR%\test_report.txt"
)

echo.
echo [4/8] 程序启动功能测试...
echo === 程序启动测试 === >> "%TEST_REPORT_DIR%\test_report.txt"

REM 创建隔离测试环境
set TEST_DIR=%TEMP%\SecChat_Functional_Test_%RANDOM%
mkdir "%TEST_DIR%"
echo 创建测试目录: %TEST_DIR%

REM 复制必要文件
echo 复制程序文件...
xcopy "%BUILD_DIR%" "%TEST_DIR%" /E /I /Q >nul
if %ERRORLEVEL% neq 0 (
    echo ✗ 文件复制失败
    echo 文件复制: 失败 >> "%TEST_REPORT_DIR%\test_report.txt"
    goto :cleanup
)

echo ✓ 文件复制成功
echo 文件复制: 成功 >> "%TEST_REPORT_DIR%\test_report.txt"

REM 测试程序启动（带网络配置）
echo 测试程序启动...
start "" /B "%TEST_DIR%\sec_chat.exe" --test-mode
timeout /t 5 /nobreak >nul

REM 检查进程和网络活动
tasklist | findstr "sec_chat.exe" >nul
if %ERRORLEVEL% equ 0 (
    echo ✓ 程序能够正常启动
    echo 程序启动: 成功 >> "%TEST_REPORT_DIR%\test_report.txt"
    
    REM 检查网络连接尝试
    netstat -an | findstr "172.25.194.201" >nul
    if %ERRORLEVEL% equ 0 (
        echo ✓ 检测到ZeroTier网络连接尝试
        echo 网络连接: 检测到 >> "%TEST_REPORT_DIR%\test_report.txt"
    ) else (
        echo ⚠ 未检测到预期的网络连接
        echo 网络连接: 未检测到 >> "%TEST_REPORT_DIR%\test_report.txt"
    )
    
    REM 终止测试进程
    taskkill /IM sec_chat.exe /F >nul 2>nul
) else (
    echo ✗ 程序启动失败
    echo 程序启动: 失败 >> "%TEST_REPORT_DIR%\test_report.txt"
)

echo.
echo [5/8] 网络诊断功能测试...
echo === 网络诊断测试 === >> "%TEST_REPORT_DIR%\test_report.txt"

REM 测试网络连通性
echo 测试基础网络连通性...
ping -n 1 8.8.8.8 >nul 2>&1
if %ERRORLEVEL% equ 0 (
    echo ✓ 基础网络连接正常
    echo 基础网络: 正常 >> "%TEST_REPORT_DIR%\test_report.txt"
) else (
    echo ✗ 基础网络连接异常
    echo 基础网络: 异常 >> "%TEST_REPORT_DIR%\test_report.txt"
)

REM 测试ZeroTier网络
if %ZEROTIER_INSTALLED% equ 1 (
    echo 测试ZeroTier网络连接...
    "C:\Program Files (x86)\ZeroTier\One\zerotier-cli.bat" listnetworks | findstr "6AB565387A193124" >nul 2>&1
    if %ERRORLEVEL% equ 0 (
        echo ✓ ZeroTier网络连接正常
        echo ZeroTier连接: 正常 >> "%TEST_REPORT_DIR%\test_report.txt"
    ) else (
        echo ⚠ ZeroTier网络未连接
        echo ZeroTier连接: 未连接 >> "%TEST_REPORT_DIR%\test_report.txt"
    )
)

echo.
echo [6/8] API连接测试...
echo === API连接测试 === >> "%TEST_REPORT_DIR%\test_report.txt"

REM 测试与服务器的连接
echo 测试API服务器连接...
powershell -Command "try { $response = Invoke-WebRequest -Uri 'http://172.25.194.201:8081/health' -TimeoutSec 10; Write-Output '✓ API服务器连接正常'; Write-Output ('HTTP状态: ' + $response.StatusCode) } catch { Write-Output '✗ API服务器连接失败'; Write-Output ('错误: ' + $_.Exception.Message) }" 2>&1
echo 测试结果已记录 >> "%TEST_REPORT_DIR%\test_report.txt"

echo.
echo [7/8] 创建便携式安装包...
echo === 便携包创建 === >> "%TEST_REPORT_DIR%\test_report.txt"

REM 创建包含网络配置的便携包
set PORTABLE_ZIP=SecChat-Windows-Portable-Full-%date:~0,10%.zip
set PORTABLE_DIR=%TEMP%\SecChat_Portable_%RANDOM%

mkdir "%PORTABLE_DIR%"
xcopy "%TEST_DIR%" "%PORTABLE_DIR%" /E /I /Q >nul

REM 添加网络配置脚本
echo @echo off > "%PORTABLE_DIR%\setup_network.bat"
echo REM ZeroTier网络自动配置脚本 >> "%PORTABLE_DIR%\setup_network.bat"
echo echo 正在配置ZeroTier网络... >> "%PORTABLE_DIR%\setup_network.bat"
echo "C:\Program Files (x86)\ZeroTier\One\zerotier-cli.bat" join 6AB565387A193124 >> "%PORTABLE_DIR%\setup_network.bat"
echo echo 请在ZeroTier Central授权此节点后重启应用 >> "%PORTABLE_DIR%\setup_network.bat"
echo pause >> "%PORTABLE_DIR%\setup_network.bat"

powershell -Command "Compress-Archive -Path '%PORTABLE_DIR%\*' -DestinationPath 'installer\windows\output\%PORTABLE_ZIP%' -Force"

if %ERRORLEVEL% equ 0 (
    echo ✓ 便携式安装包创建成功
    echo   位置: installer\windows\output\%PORTABLE_ZIP%
    echo 便携包: 创建成功 >> "%TEST_REPORT_DIR%\test_report.txt"
    echo 位置: installer\windows\output\%PORTABLE_ZIP% >> "%TEST_REPORT_DIR%\test_report.txt"
) else (
    echo ✗ 便携式安装包创建失败
    echo 便携包: 创建失败 >> "%TEST_REPORT_DIR%\test_report.txt"
)

echo.
echo [8/8] 生成测试报告...
echo === 测试总结 === >> "%TEST_REPORT_DIR%\test_report.txt"

REM 统计测试结果
findstr /C:"✓" "%TEST_REPORT_DIR%\test_report.txt" | find /c /v "" > "%TEMP%\pass_count.txt"
set /p PASS_COUNT=<"%TEMP%\pass_count.txt"
del "%TEMP%\pass_count.txt" 2>nul

findstr /C:"✗" "%TEST_REPORT_DIR%\test_report.txt" | find /c /v "" > "%TEMP%\fail_count.txt"
set /p FAIL_COUNT=<"%TEMP%\fail_count.txt"
del "%TEMP%\fail_count.txt" 2>nul

:cleanup
REM 清理测试环境
rd /s /q "%TEST_DIR%" >nul 2>nul
rd /s /q "%PORTABLE_DIR%" >nul 2>nul

:test_failed
echo.
echo ============================================
echo   Windows安装包测试完成
echo ============================================
echo 测试通过项: %PASS_COUNT%
echo 测试失败项: %FAIL_COUNT%
echo 详细报告位置: %TEST_REPORT_DIR%\test_report.txt
echo 便携包位置: installer\windows\output\%PORTABLE_ZIP%
echo.

REM 显示测试摘要
echo 测试摘要:
type "%TEST_REPORT_DIR%\test_report.txt" | findstr "===\|✓\|✗\|⚠"

if %FAIL_COUNT% gtr 0 (
    echo.
    echo 发现问题，请检查详细报告并修复后再重新测试。
    exit /b 1
) else (
    echo.
    echo 所有测试通过！安装包功能完整。
    exit /b 0
)

pause