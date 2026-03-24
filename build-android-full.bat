@echo off
REM 企业安全聊天应用 - Android构建和测试脚本
REM 集成ZeroTier网络配置、Docker代理设置、镜像加速器配置

echo ============================================
echo   企业安全聊天应用Android构建
echo ============================================
echo.

REM 设置环境变量
set APP_NAME=SecChat
set APP_VERSION=1.0.0
set BUILD_DIR=%~dp0apps\flutter_app\build\app\outputs\flutter-apk
set OUTPUT_DIR=%~dp0installer\android\output

REM 检查Flutter环境
where flutter >nul 2>nul
if %ERRORLEVEL% neq 0 (
    echo [错误] 未找到Flutter，请确保Flutter已安装并添加到PATH
    exit /b 1
)

echo [1/6] 清理旧构建...
cd /d "%~dp0apps\flutter_app"
call flutter clean
if %ERRORLEVEL% neq 0 (
    echo [错误] Flutter clean 失败
    exit /b 1
)

echo [2/6] 获取依赖...
call flutter pub get
if %ERRORLEVEL% neq 0 (
    echo [错误] Flutter pub get 失败
    exit /b 1
)

echo [3/6] 构建Android Release版本...
call flutter build apk --release --target-platform android-arm64
if %ERRORLEVEL% neq 0 (
    echo [错误] APK构建失败
    exit /b 1
)

echo [4/6] 构建Android App Bundle...
call flutter build appbundle --release
if %ERRORLEVEL% neq 0 (
    echo [错误] App Bundle构建失败
    exit /b 1
)

cd /d "%~dp0"

echo [5/6] 创建输出目录...
if not exist "%OUTPUT_DIR%" mkdir "%OUTPUT_DIR%"

echo [6/6] 复制构建产物并创建网络配置包...

REM 复制APK文件
copy "%BUILD_DIR%\app-release.apk" "%OUTPUT_DIR%\SecChat-Android-%APP_VERSION%.apk" >nul
if %ERRORLEVEL% equ 0 (
    echo. ? APK文件已复制: SecChat-Android-%APP_VERSION%.apk
) else (
    echo. ? APK文件复制失败
)

REM 复制AAB文件
copy "%~dp0apps\flutter_app\build\app\outputs\bundle\release\app-release.aab" "%OUTPUT_DIR%\SecChat-Android-%APP_VERSION%.aab" >nul
if %ERRORLEVEL% equ 0 (
    echo ? AAB文件已复制: SecChat-Android-%APP_VERSION%.aab
) else (
    echo ? AAB文件复制失败
)

REM 创建包含网络配置的完整安装包
set FULL_PACKAGE_DIR=%TEMP%\SecChat_Android_Full_%RANDOM%
mkdir "%FULL_PACKAGE_DIR%"

REM 复制应用文件
copy "%OUTPUT_DIR%\SecChat-Android-%APP_VERSION%.apk" "%FULL_PACKAGE_DIR%\SecChat.apk" >nul

REM 创建ZeroTier配置说明
echo # ZeroTier网络配置说明 > "%FULL_PACKAGE_DIR%\ZeroTier_Setup_Guide.txt"
echo. >> "%FULL_PACKAGE_DIR%\ZeroTier_Setup_Guide.txt"
echo ## 安装ZeroTier客户端 >> "%FULL_PACKAGE_DIR%\ZeroTier_Setup_Guide.txt"
echo 1. 从Google Play下载并安装ZeroTier >> "%FULL_PACKAGE_DIR%\ZeroTier_Setup_Guide.txt"
echo 2. 打开ZeroTier应用 >> "%FULL_PACKAGE_DIR%\ZeroTier_Setup_Guide.txt"
echo 3. 点击"Join Network" >> "%FULL_PACKAGE_DIR%\ZeroTier_Setup_Guide.txt"
echo 4. 输入网络ID: 6AB565387A193124 >> "%FULL_PACKAGE_DIR%\ZeroTier_Setup_Guide.txt"
echo 5. 在 https://my.zerotier.com 授权设备 >> "%FULL_PACKAGE_DIR%\ZeroTier_Setup_Guide.txt"
echo. >> "%FULL_PACKAGE_DIR%\ZeroTier_Setup_Guide.txt"
echo ## 网络配置详情 >> "%FULL_PACKAGE_DIR%\ZeroTier_Setup_Guide.txt"
echo - 网络ID: 6AB565387A193124 >> "%FULL_PACKAGE_DIR%\ZeroTier_Setup_Guide.txt"
echo - 分配IP段: 172.25.194.0/24 >> "%FULL_PACKAGE_DIR%\ZeroTier_Setup_Guide.txt"
echo - 网关IP: 172.25.194.201 >> "%FULL_PACKAGE_DIR%\ZeroTier_Setup_Guide.txt"

REM 创建Docker代理配置说明
echo # Docker代理配置说明 > "%FULL_PACKAGE_DIR%\Docker_Proxy_Config.txt"
echo. >> "%FULL_PACKAGE_DIR%\Docker_Proxy_Config.txt"
echo ## 注意事项 >> "%FULL_PACKAGE_DIR%\Docker_Proxy_Config.txt"
echo Docker代理配置为可选项，仅在需要通过代理访问外部资源时使用。 >> "%FULL_PACKAGE_DIR%\Docker_Proxy_Config.txt"
echo 端口9993是ZeroTier的UDP通信端口，请勿用作HTTP代理端口。 >> "%FULL_PACKAGE_DIR%\Docker_Proxy_Config.txt"
echo. >> "%FULL_PACKAGE_DIR%\Docker_Proxy_Config.txt"
echo ## 如果在支持root的设备上使用Docker: >> "%FULL_PACKAGE_DIR%\Docker_Proxy_Config.txt"
echo 1. 确保设备已root >> "%FULL_PACKAGE_DIR%\Docker_Proxy_Config.txt"
echo 2. 安装Termux应用 >> "%FULL_PACKAGE_DIR%\Docker_Proxy_Config.txt"
echo 3. 在Termux中配置Docker代理（如有HTTP代理服务）: >> "%FULL_PACKAGE_DIR%\Docker_Proxy_Config.txt"
echo    export http_proxy=http://YOUR_PROXY_HOST:8118 >> "%FULL_PACKAGE_DIR%\Docker_Proxy_Config.txt"
echo    export https_proxy=http://YOUR_PROXY_HOST:8118 >> "%FULL_PACKAGE_DIR%\Docker_Proxy_Config.txt"
echo. >> "%FULL_PACKAGE_DIR%\Docker_Proxy_Config.txt"
echo ## 推荐：使用国内镜像加速器（无需代理） >> "%FULL_PACKAGE_DIR%\Docker_Proxy_Config.txt"
echo    配置daemon.json添加: >> "%FULL_PACKAGE_DIR%\Docker_Proxy_Config.txt"
echo    "registry-mirrors": ["https://docker.mirrors.ustc.edu.cn"] >> "%FULL_PACKAGE_DIR%\Docker_Proxy_Config.txt"

REM 创建完整的ZIP包
set FULL_ZIP_NAME=SecChat-Android-Full-Package-%APP_VERSION%.zip
powershell -Command "Compress-Archive -Path '%FULL_PACKAGE_DIR%\*' -DestinationPath '%OUTPUT_DIR%\%FULL_ZIP_NAME%' -Force"

if %ERRORLEVEL% equ 0 (
    echo ? 完整安装包已创建: %FULL_ZIP_NAME%
) else (
    echo ? 完整安装包创建失败
)

REM 清理临时目录
rd /s /q "%FULL_PACKAGE_DIR%" >nul 2>nul

echo.
echo ============================================
echo   Android构建完成!
echo ============================================
echo.
echo 输出文件:
echo   - APK: %OUTPUT_DIR%\SecChat-Android-%APP_VERSION%.apk
echo   - AAB: %OUTPUT_DIR%\SecChat-Android-%APP_VERSION%.aab
echo   - 完整包: %OUTPUT_DIR%\%FULL_ZIP_NAME%
echo.
echo 包含的网络配置:
echo   ? ZeroTier网络配置 (172.25.194.0/24)
echo   ? Docker代理设置说明
echo   ? 网络安全配置
echo.
echo 安装说明:
echo   1. 安装APK文件
echo   2. 按照ZeroTier配置指南设置网络
echo   3. 启动应用并连接到服务器
echo.

pause