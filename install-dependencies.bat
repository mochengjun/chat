@echo off
chcp 65001 >nul
REM ============================================================
REM 一键安装开发环境 - Windows版本
REM ============================================================

echo.
echo ============================================================
echo    企业级安全聊天应用 - 开发环境安装向导
echo ============================================================
echo.

REM 检查管理员权限
net session >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo [警告] 建议以管理员身份运行此脚本
    echo        某些安装步骤可能需要管理员权限
    echo.
)

echo 正在检查系统环境...
echo.

REM ============================================================
REM 步骤 1: 检查已安装的工具
REM ============================================================

echo [步骤 1/6] 检查已安装的工具...
echo.

REM Node.js
where node >nul 2>&1
if %ERRORLEVEL% equ 0 (
    for /f "tokens=*" %%v in ('node --version') do set NODE_VERSION=%%v
    echo   [✓] Node.js: %NODE_VERSION%
) else (
    echo   [✗] Node.js: 未安装
)

REM NPM
where npm >nul 2>&1
if %ERRORLEVEL% equ 0 (
    for /f "tokens=*" %%v in ('npm --version') do set NPM_VERSION=%%v
    echo   [✓] NPM: %NPM_VERSION%
) else (
    echo   [✗] NPM: 未安装
)

REM Go
where go >nul 2>&1
if %ERRORLEVEL% equ 0 (
    for /f "tokens=3" %%v in ('go version 2^>nul') do set GO_VERSION=%%v
    echo   [✓] Go: %GO_VERSION%
) else (
    echo   [✗] Go: 未安装
    set NEED_GO=1
)

REM Flutter
where flutter >nul 2>&1
if %ERRORLEVEL% equ 0 (
    for /f "tokens=2" %%v in ('flutter --version 2^>nul ^| findstr /r "^Flutter"') do set FLUTTER_VERSION=%%v
    echo   [✓] Flutter: %FLUTTER_VERSION%
) else (
    echo   [✗] Flutter: 未安装
    set NEED_FLUTTER=1
)

REM Git
where git >nul 2>&1
if %ERRORLEVEL% equ 0 (
    echo   [✓] Git: 已安装
) else (
    echo   [✗] Git: 未安装
)

echo.

REM ============================================================
REM 步骤 2: 下载安装工具
REM ============================================================

echo [步骤 2/6] 准备安装工具...
echo.

REM 检查是否有 winget (Windows Package Manager)
where winget >nul 2>&1
if %ERRORLEVEL% equ 0 (
    echo   [✓] 检测到 winget - 可以自动安装
    set HAS_WINGET=1
) else (
    echo   [✗] 未检测到 winget - 需要手动下载
    set HAS_WINGET=0
)

REM 检查是否有 Chocolatey
where choco >nul 2>&1
if %ERRORLEVEL% equ 0 (
    echo   [✓] 检测到 Chocolatey - 可以自动安装
    set HAS_CHOCO=1
) else (
    echo   [✗] 未检测到 Chocolatey
    set HAS_CHOCO=0
)

echo.

REM ============================================================
REM 步骤 3: 安装 Go
REM ============================================================

if defined NEED_GO (
    echo [步骤 3/6] 安装 Go 环境...
    echo.
    
    echo 请选择安装方式:
    echo   1. 自动安装 (使用 winget 或 Chocolatey)
    echo   2. 手动安装 (下载安装包)
    echo   3. 跳过
    echo.
    set /p GO_CHOICE="请输入选择 (1/2/3): "
    
    if "!GO_CHOICE!"=="1" (
        if %HAS_WINGET%==1 (
            echo   正在使用 winget 安装 Go...
            winget install GoLang.Go --interactive
        ) else if %HAS_CHOCO%==1 (
            echo   正在使用 Chocolatey 安装 Go...
            choco install golang -y
        ) else (
            echo   [错误] 未找到可用的包管理器
            goto :manual_go
        )
    ) else if "!GO_CHOICE!"=="2" (
        :manual_go
        echo.
        echo   请手动下载并安装 Go:
        echo   1. 访问: https://golang.org/dl/
        echo   2. 下载: go1.23.x.windows-amd64.msi
        echo   3. 双击安装程序
        echo   4. 安装完成后重启终端
        echo.
        start https://golang.org/dl/
    ) else (
        echo   跳过 Go 安装
    )
) else (
    echo [步骤 3/6] Go 已安装,跳过
)

echo.

REM ============================================================
REM 步骤 4: 安装 Flutter
REM ============================================================

if defined NEED_FLUTTER (
    echo [步骤 4/6] 安装 Flutter 环境...
    echo.
    
    echo 请选择安装方式:
    echo   1. 自动安装 (使用 Chocolatey)
    echo   2. 手动安装 (下载ZIP包)
    echo   3. 跳过
    echo.
    set /p FLUTTER_CHOICE="请输入选择 (1/2/3): "
    
    if "!FLUTTER_CHOICE!"=="1" (
        if %HAS_CHOCO%==1 (
            echo   正在使用 Chocolatey 安装 Flutter...
            choco install flutter -y
        ) else (
            echo   [错误] 未找到 Chocolatey
            goto :manual_flutter
        )
    ) else if "!FLUTTER_CHOICE!"=="2" (
        :manual_flutter
        echo.
        echo   请手动下载并安装 Flutter:
        echo   1. 访问: https://flutter.dev/docs/get-started/install/windows
        echo   2. 下载: flutter_windows_3.x.x-stable.zip
        echo   3. 解压到: C:\flutter
        echo   4. 添加到 PATH: C:\flutter\bin
        echo   5. 运行: flutter doctor
        echo.
        start https://flutter.dev/docs/get-started/install/windows
    ) else (
        echo   跳过 Flutter 安装
    )
) else (
    echo [步骤 4/6] Flutter 已安装,跳过
)

echo.

REM ============================================================
REM 步骤 5: 配置环境变量
REM ============================================================

echo [步骤 5/6] 配置环境变量和镜像源...
echo.

REM 配置 Go 代理 (如果 Go 已安装)
where go >nul 2>&1
if %ERRORLEVEL% equ 0 (
    echo   配置 Go 代理...
    go env -w GOPROXY=https://goproxy.cn,https://goproxy.io,direct
    go env -w GOSUMDB=sum.golang.google.cn
    go env -w GO111MODULE=on
    echo   [✓] Go 代理已配置: https://goproxy.cn
)

REM 配置 Flutter 镜像 (如果 Flutter 已安装)
where flutter >nul 2>&1
if %ERRORLEVEL% equ 0 (
    echo   配置 Flutter 镜像...
    setx PUB_HOSTED_URL "https://pub.flutter-io.cn" >nul 2>&1
    setx FLUTTER_STORAGE_BASE_URL "https://storage.flutter-io.cn" >nul 2>&1
    echo   [✓] Flutter 镜像已配置
)

REM 配置 NPM 镜像
where npm >nul 2>&1
if %ERRORLEVEL% equ 0 (
    echo   配置 NPM 镜像...
    npm config set registry https://registry.npmmirror.com
    echo   [✓] NPM 镜像已配置: https://registry.npmmirror.com
)

echo.

REM ============================================================
REM 步骤 6: 验证安装
REM ============================================================

echo [步骤 6/6] 验证安装结果...
echo.

where go >nul 2>&1
if %ERRORLEVEL% equ 0 (
    echo   [✓] Go: 
    go version
) else (
    echo   [✗] Go: 未安装
)

where flutter >nul 2>&1
if %ERRORLEVEL% equ 0 (
    echo   [✓] Flutter: 
    flutter --version 2>nul | findstr /r "^Flutter"
) else (
    echo   [✗] Flutter: 未安装
)

where node >nul 2>&1
if %ERRORLEVEL% equ 0 (
    echo   [✓] Node.js: 
    node --version
)

echo.
echo ============================================================
echo    安装向导完成！
echo ============================================================
echo.
echo 下一步操作:
echo   1. 如果安装了新工具,请重启终端
echo   2. 运行环境检查: check-env.bat
echo   3. 运行缓存同步: scripts\cache-manager\cache-tool-native.bat sync
echo   4. 开始构建项目: build-smart.bat
echo.

pause
