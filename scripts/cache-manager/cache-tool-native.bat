@echo off
chcp 65001 >nul
REM ============================================================
REM 智能编译缓存工具 - 纯批处理版本(无需Python)
REM 使用方法: cache-tool-native.bat <command> [options]
REM
REM 命令:
REM   check         检查缓存状态
REM   sync          同步依赖到缓存
REM   clean         清理缓存
REM   stats         显示缓存统计
REM
REM 选项:
REM   --project {flutter|go|nodejs|all}   指定项目类型
REM   --offline                           离线模式
REM   --verbose                           详细输出
REM ============================================================

setlocal EnableDelayedExpansion

set "SCRIPT_DIR=%~dp0"
set "PROJECT_ROOT=%SCRIPT_DIR%..\.."
set "CACHE_DIR=%PROJECT_ROOT%\.cache"

REM 解析参数
set "COMMAND="
set "PROJECT_TYPE=all"
set "OFFLINE_MODE=0"
set "VERBOSE=0"

:parse_args
if "%~1"=="" goto :execute_command
if /i "%~1"=="check" set "COMMAND=check" & shift & goto :parse_args
if /i "%~1"=="sync" set "COMMAND=sync" & shift & goto :parse_args
if /i "%~1"=="clean" set "COMMAND=clean" & shift & goto :parse_args
if /i "%~1"=="stats" set "COMMAND=stats" & shift & goto :parse_args
if /i "%~1"=="--project" set "PROJECT_TYPE=%~2" & shift & shift & goto :parse_args
if /i "%~1"=="--offline" set "OFFLINE_MODE=1" & shift & goto :parse_args
if /i "%~1"=="--verbose" set "VERBOSE=1" & shift & goto :parse_args
if /i "%~1"=="--help" goto :show_help
shift
goto :parse_args

:execute_command

if "%COMMAND%"=="" goto :show_help

REM 创建缓存目录
if not exist "%CACHE_DIR%" mkdir "%CACHE_DIR%"

REM 执行相应命令
if "%COMMAND%"=="check" goto :do_check
if "%COMMAND%"=="sync" goto :do_sync
if "%COMMAND%"=="clean" goto :do_clean
if "%COMMAND%"=="stats" goto :do_stats

goto :end

REM ============================================================
REM check 命令
REM ============================================================

:do_check
echo.
echo ============================================================
echo    缓存状态检查
echo ============================================================
echo.

REM Flutter
if "%PROJECT_TYPE%"=="flutter" goto :check_flutter
if "%PROJECT_TYPE%"=="all" goto :check_flutter
goto :check_go

:check_flutter
echo [Flutter] 检查依赖缓存...
echo.

REM 查找 pubspec.yaml 文件
set PUBSPEC_COUNT=0
for /r "%PROJECT_ROOT%\apps\flutter_app" %%f in (pubspec.yaml) do (
    set /a PUBSPEC_COUNT+=1
    if exist "%%f" (
        echo   Pubspec 文件: %%f
    )
)

echo   Pubspec 文件数: %PUBSPEC_COUNT%

REM 检查 Flutter Pub Cache
set "PUB_CACHE=%LOCALAPPDATA%\Pub\Cache"
if not exist "%PUB_CACHE%" set "PUB_CACHE=%USERPROFILE%\.pub-cache"

set CACHED_PKGS=0
if exist "%PUB_CACHE%\hosted" (
    for /d %%d in ("%PUB_CACHE%\hosted\*") do (
        for /d %%p in ("%%d\*") do set /a CACHED_PKGS+=1
    )
)

echo   系统缓存包数: %CACHED_PKGS%
echo   缓存位置: %PUB_CACHE%
echo.

REM 检查本地缓存
if exist "%CACHE_DIR%\flutter\pub-cache" (
    set LOCAL_CACHED=0
    for /d %%d in ("%CACHE_DIR%\flutter\pub-cache\hosted\*") do (
        for /d %%p in ("%%d\*") do set /a LOCAL_CACHED+=1
    )
    echo   本地缓存包数: !LOCAL_CACHED!
) else (
    echo   本地缓存: 未创建
)
echo.

if "%PROJECT_TYPE%"=="flutter" goto :end

REM Go
:check_go
echo [Go] 检查模块缓存...
echo.

REM 查找 go.mod 文件
set GO_MOD_COUNT=0
for /r "%PROJECT_ROOT%\services" %%f in (go.mod) do (
    if exist "%%f" set /a GO_MOD_COUNT+=1
)

echo   go.mod 文件数: %GO_MOD_COUNT%

REM 检查 Go Module Cache
set "GOPATH=%USERPROFILE%\go"
if defined GOPATH_ENV set "GOPATH=%GOPATH_ENV%"
set "GO_MOD_CACHE=%GOPATH%\pkg\mod"

set CACHED_MODS=0
if exist "%GO_MOD_CACHE%" (
    for /d %%d in ("%GO_MOD_CACHE%\*") do set /a CACHED_MODS+=1
)

echo   系统缓存模块数: %CACHED_MODS%
echo   缓存位置: %GO_MOD_CACHE%
echo.

REM 检查本地缓存
if exist "%CACHE_DIR%\go\mod-cache" (
    set LOCAL_MODS=0
    for /d %%d in ("%CACHE_DIR%\go\mod-cache\*") do set /a LOCAL_MODS+=1
    echo   本地缓存模块数: !LOCAL_MODS!
) else (
    echo   本地缓存: 未创建
)
echo.

if "%PROJECT_TYPE%"=="go" goto :end

REM Node.js
:check_nodejs
echo [Node.js] 检查包缓存...
echo.

REM 查找 package.json 文件
set PKG_JSON_COUNT=0
if exist "%PROJECT_ROOT%\web-client\package.json" set /a PKG_JSON_COUNT+=1

echo   package.json 文件数: %PKG_JSON_COUNT%

REM 检查 NPM Cache
set "NPM_CACHE=%APPDATA%\npm-cache"
if defined NPM_CONFIG_CACHE set "NPM_CACHE=%NPM_CONFIG_CACHE%"

echo   NPM 缓存位置: %NPM_CACHE%

REM 检查本地缓存
if exist "%CACHE_DIR%\nodejs\npm-cache" (
    echo   本地缓存: 存在
) else (
    echo   本地缓存: 未创建
)
echo.

goto :end

REM ============================================================
REM sync 命令
REM ============================================================

:do_sync
echo.
echo ============================================================
echo    同步依赖到缓存
if "%OFFLINE_MODE%"=="1" echo    [离线模式]
echo ============================================================
echo.

REM 设置环境变量
set "PUB_HOSTED_URL=https://pub.flutter-io.cn"
set "FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn"
set "GOPROXY=https://goproxy.cn,https://goproxy.io,direct"
set "npm_config_registry=https://registry.npmmirror.com"

REM Flutter
if "%PROJECT_TYPE%"=="flutter" goto :sync_flutter
if "%PROJECT_TYPE%"=="all" goto :sync_flutter
goto :sync_go

:sync_flutter
echo [Flutter] 同步依赖...
echo.

if exist "%PROJECT_ROOT%\apps\flutter_app\pubspec.yaml" (
    cd /d "%PROJECT_ROOT%\apps\flutter_app"
    
    REM 设置本地缓存路径
    set "PUB_CACHE=%CACHE_DIR%\flutter\pub-cache"
    if not exist "!PUB_CACHE!" mkdir "!PUB_CACHE!"
    
    if "%OFFLINE_MODE%"=="1" (
        flutter pub get --offline
    ) else (
        flutter pub get
    )
    
    if !ERRORLEVEL! equ 0 (
        echo   [OK] Flutter 依赖同步成功
    ) else (
        echo   [失败] Flutter 依赖同步失败
    )
    cd /d "%SCRIPT_DIR%"
)
echo.

if "%PROJECT_TYPE%"=="flutter" goto :end

REM Go
:sync_go
echo [Go] 同步模块...
echo.

REM 设置本地缓存路径
set "GOPATH=%CACHE_DIR%\go"
set "GOMODCACHE=%CACHE_DIR%\go\mod-cache"
if not exist "%GOMODCACHE%" mkdir "%GOMODCACHE%"

for /r "%PROJECT_ROOT%\services" %%f in (go.mod) do (
    if exist "%%f" (
        set "MOD_DIR=%%~dpf"
        echo   处理: %%~dpf
        
        pushd "%%~dpf"
        
        if "%OFFLINE_MODE%"=="1" (
            set "GOPROXY=off"
            go mod download
        ) else (
            go mod download
        )
        
        if !ERRORLEVEL! equ 0 (
            echo   [OK] Go 模块同步成功
        ) else (
            echo   [失败] Go 模块同步失败
        )
        
        popd
    )
)
echo.

if "%PROJECT_TYPE%"=="go" goto :end

REM Node.js
:sync_nodejs
echo [Node.js] 同步包...
echo.

REM 设置本地缓存路径
set "npm_config_cache=%CACHE_DIR%\nodejs\npm-cache"
if not exist "!npm_config_cache!" mkdir "!npm_config_cache!"

if exist "%PROJECT_ROOT%\web-client\package.json" (
    cd /d "%PROJECT_ROOT%\web-client"
    
    if "%OFFLINE_MODE%"=="1" (
        npm install --offline --prefer-offline
    ) else (
        npm install
    )
    
    if !ERRORLEVEL! equ 0 (
        echo   [OK] Node.js 包同步成功
    ) else (
        echo   [失败] Node.js 包同步失败
    )
    
    cd /d "%SCRIPT_DIR%"
)
echo.

goto :end

REM ============================================================
REM clean 命令
REM ============================================================

:do_clean
echo.
echo ============================================================
echo    清理缓存
echo ============================================================
echo.

if exist "%CACHE_DIR%\flutter" (
    echo 清理 Flutter 缓存...
    rmdir /s /q "%CACHE_DIR%\flutter"
    echo   [OK] Flutter 缓存已清理
)

if exist "%CACHE_DIR%\go" (
    echo 清理 Go 缓存...
    rmdir /s /q "%CACHE_DIR%\go"
    echo   [OK] Go 缓存已清理
)

if exist "%CACHE_DIR%\nodejs" (
    echo 清理 Node.js 缓存...
    rmdir /s /q "%CACHE_DIR%\nodejs"
    echo   [OK] Node.js 缓存已清理
)

echo.
echo 缓存清理完成
goto :end

REM ============================================================
REM stats 命令
REM ============================================================

:do_stats
echo.
echo ============================================================
echo    缓存统计信息
echo ============================================================
echo.

REM 计算缓存大小
set TOTAL_SIZE=0

if exist "%CACHE_DIR%" (
    echo 缓存目录: %CACHE_DIR%
    echo.
    
    REM Flutter
    if exist "%CACHE_DIR%\flutter" (
        for /f %%s in ('dir /s /-c "%CACHE_DIR%\flutter" 2^>nul ^| findstr /c:"File(s)"') do (
            for /f "tokens=1" %%a in ("%%s") do set FLUTTER_SIZE=%%a
        )
        if defined FLUTTER_SIZE (
            set /a TOTAL_SIZE+=FLUTTER_SIZE
            echo [Flutter] 缓存大小: !FLUTTER_SIZE! 字节
        )
    )
    
    REM Go
    if exist "%CACHE_DIR%\go" (
        for /f %%s in ('dir /s /-c "%CACHE_DIR%\go" 2^>nul ^| findstr /c:"File(s)"') do (
            for /f "tokens=1" %%a in ("%%s") do set GO_SIZE=%%a
        )
        if defined GO_SIZE (
            set /a TOTAL_SIZE+=GO_SIZE
            echo [Go] 缓存大小: !GO_SIZE! 字节
        )
    )
    
    REM Node.js
    if exist "%CACHE_DIR%\nodejs" (
        for /f %%s in ('dir /s /-c "%CACHE_DIR%\nodejs" 2^>nul ^| findstr /c:"File(s)"') do (
            for /f "tokens=1" %%a in ("%%s") do set NODEJS_SIZE=%%a
        )
        if defined NODEJS_SIZE (
            set /a TOTAL_SIZE+=NODEJS_SIZE
            echo [Node.js] 缓存大小: !NODEJS_SIZE! 字节
        )
    )
    
    echo.
    echo 总缓存大小: %TOTAL_SIZE% 字节
) else (
    echo 缓存目录不存在
)

goto :end

REM ============================================================
REM 帮助信息
REM ============================================================

:show_help
echo.
echo 使用方法: %~nx0 ^<command^> [options]
echo.
echo 命令:
echo   check         检查缓存状态
echo   sync          同步依赖到缓存
echo   clean         清理缓存
echo   stats         显示缓存统计
echo.
echo 选项:
echo   --project {flutter^|go^|nodejs^|all}   指定项目类型 (默认: all)
echo   --offline                           离线模式
echo   --verbose                           详细输出
echo   --help                              显示此帮助信息
echo.
echo 示例:
echo   %~nx0 check                    # 检查所有项目的缓存状态
echo   %~nx0 sync --offline           # 离线模式同步依赖
echo   %~nx0 clean                    # 清理所有缓存
echo   %~nx0 stats                    # 显示缓存统计
echo.
goto :end

:end
endlocal
