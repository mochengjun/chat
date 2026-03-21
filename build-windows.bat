@echo off
REM ============================================================
REM 企业安全聊天应用 - Windows客户端构建脚本
REM 支持本地SQLite3库构建，避免网络下载依赖
REM 使用方法: build-windows.bat [选项]
REM 选项:
REM   --offline    离线模式构建（使用本地缓存）
REM   --clean      清理构建缓存
REM   --no-zip     不创建ZIP包
REM ============================================================

setlocal EnableDelayedExpansion

echo.
echo ============================================================
echo    企业安全聊天应用 - Windows客户端构建
echo    版本: 1.0.0
echo ============================================================
echo.

REM 保存脚本所在目录
set "SCRIPT_DIR=%~dp0"
cd /d "%SCRIPT_DIR%"

REM 设置默认变量
set "APP_NAME=SecChat"
set "APP_VERSION=1.0.0"
set "OFFLINE_MODE=0"
set "CLEAN_BUILD=0"
set "CREATE_ZIP=1"
set "FLUTTER_APP_DIR=%SCRIPT_DIR%apps\flutter_app"
set "BUILD_DIR=%FLUTTER_APP_DIR%\build\windows\x64\runner\Release"
set "OUTPUT_DIR=%SCRIPT_DIR%installer\windows\output"
set "SQLITE_CACHE_DIR=%SCRIPT_DIR%sqlite-cache"
set "SQLITE_DLL_ZIP=%SCRIPT_DIR%sqlite-dll.zip"
set "MAX_RETRIES=3"

REM 解析命令行参数
:parse_args
if "%~1"=="" goto :args_done
if /i "%~1"=="--offline" (
    set "OFFLINE_MODE=1"
    shift
    goto :parse_args
)
if /i "%~1"=="--clean" (
    set "CLEAN_BUILD=1"
    shift
    goto :parse_args
)
if /i "%~1"=="--no-zip" (
    set "CREATE_ZIP=0"
    shift
    goto :parse_args
)
if /i "%~1"=="--help" goto :show_help
if /i "%~1"=="-h" goto :show_help
shift
goto :parse_args

:args_done

if "%OFFLINE_MODE%"=="1" (
    echo [配置] 离线模式构建
) else (
    echo [配置] 在线模式构建
)
echo.

REM ============================================================
REM 步骤 0: 初始化构建环境
REM ============================================================

echo [步骤 0/7] 初始化构建环境...
echo.

REM 清除可能干扰构建的代理环境变量
set "http_proxy="
set "https_proxy="
set "HTTP_PROXY="
set "HTTPS_PROXY="
set "no_proxy="
set "NO_PROXY="
echo   [OK] 已清除代理环境变量

REM 设置国内镜像（加速下载）
set "PUB_HOSTED_URL=https://pub.flutter-io.cn"
set "FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn"
echo   [OK] 已配置国内镜像源

echo.

REM ============================================================
REM 步骤 1: 环境检查
REM ============================================================

echo [步骤 1/7] 环境检查...
echo.

REM 检查 Flutter 环境
where flutter >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo [错误] Flutter 未安装或未添加到 PATH
    echo        请访问 https://flutter.dev/docs/get-started/install
    goto :error_exit
)
for /f "tokens=2" %%v in ('flutter --version 2^>nul ^| findstr /r "^Flutter"') do set FLUTTER_VERSION=%%v
echo   [OK] Flutter 版本: %FLUTTER_VERSION%

REM 检查 Visual Studio Build Tools
where cl >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo   [提示] Visual Studio Build Tools 未在 PATH 中
    echo          Flutter 会自动查找已安装的 Visual Studio
) else (
    echo   [OK] Visual Studio Build Tools 可用
)

REM 预下载 NuGet（某些插件需要）
call :setup_nuget

REM 网络检查（非离线模式）
if "%OFFLINE_MODE%"=="0" (
    echo.
    echo   网络状态检查...
    ping -n 1 8.8.8.8 >nul 2>&1
    if !ERRORLEVEL! equ 0 (
        echo   [OK] 基础网络连接正常
    ) else (
        echo   [警告] 网络连接异常，建议使用 --offline 模式
    )
)

echo.

REM ============================================================
REM 步骤 2: 检查本地SQLite3库
REM ============================================================

echo [步骤 2/7] 检查本地SQLite3库...
echo.

call :check_sqlite_cache

echo.

REM ============================================================
REM 步骤 3: 清理旧构建
REM ============================================================

cd /d "%FLUTTER_APP_DIR%"

REM 始终进行基本清理以避免MSB8066错误
echo [步骤 3/7] 清理旧构建...
echo.

if "%CLEAN_BUILD%"=="1" (
    echo   执行完整清理...
    
    REM Flutter clean
    call flutter clean
    
    REM 删除 Windows 构建目录（解决 MSB8066 错误）
    if exist "build\windows" (
        echo   删除 build\windows 目录...
        rmdir /s /q "build\windows" 2>nul
    )
    
    REM 删除 .dart_tool
    if exist ".dart_tool" (
        echo   删除 .dart_tool 目录...
        rmdir /s /q ".dart_tool" 2>nul
    )
    
    echo   [OK] 完整清理完成
) else (
    REM 即使不指定 --clean，也清理可能导致问题的缓存
    if exist "build\windows\x64\CMakeFiles" (
        echo   清理 CMake 缓存以避免构建错误...
        rmdir /s /q "build\windows\x64\CMakeFiles" 2>nul
    )
    if exist "build\windows\x64\flutter" (
        echo   清理 flutter 构建缓存...
        rmdir /s /q "build\windows\x64\flutter" 2>nul
    )
    echo   [OK] 基本清理完成
)

echo.

REM ============================================================
REM 步骤 4: 获取依赖
REM ============================================================

echo [步骤 4/7] 获取依赖...
echo.

cd /d "%FLUTTER_APP_DIR%"

if "%OFFLINE_MODE%"=="1" (
    echo   使用离线模式获取依赖...
    call flutter pub get --offline
    if !ERRORLEVEL! neq 0 (
        echo [错误] 离线模式依赖获取失败
        echo.
        echo 解决方案:
        echo   1. 请先在有网络时运行: flutter pub get
        echo   2. 确保所有依赖已缓存
        goto :error_exit
    )
    echo   [OK] 离线依赖获取成功
) else (
    REM 在线模式（带重试机制）
    set RETRY_COUNT=0
    
    :retry_pub_get
    set /a RETRY_COUNT+=1
    echo   获取依赖 - 第 !RETRY_COUNT!/%MAX_RETRIES% 次尝试...
    
    call flutter pub get
    if !ERRORLEVEL! equ 0 (
        echo   [OK] 依赖获取成功
        goto :pub_get_done
    )
    
    if !RETRY_COUNT! lss %MAX_RETRIES% (
        echo   [警告] 依赖获取失败，等待5秒后重试...
        timeout /t 5 /nobreak >nul
        goto :retry_pub_get
    )
    
    echo [警告] 在线依赖获取失败，尝试离线模式...
    call flutter pub get --offline
    if !ERRORLEVEL! neq 0 (
        echo [错误] 依赖获取失败 - 已重试%MAX_RETRIES%次
        echo.
        echo 建议解决方案:
        echo   1. 检查网络连接
        echo   2. 使用国内镜像: set PUB_HOSTED_URL=https://pub.flutter-io.cn
        echo   3. 使用离线模式: build-windows.bat --offline
        goto :error_exit
    )
    echo   [OK] 使用离线缓存完成依赖获取
)

:pub_get_done
echo.

REM ============================================================
REM 步骤 5: 构建 Windows Release
REM ============================================================

echo [步骤 5/7] 构建 Windows Release...
echo.

cd /d "%FLUTTER_APP_DIR%"

call flutter build windows --release
if %ERRORLEVEL% neq 0 (
    echo [错误] Windows Release 构建失败
    echo.
    echo 可能的解决方案:
    echo   1. 运行: build-windows.bat --clean 进行完整清理后重试
    echo   2. 手动删除 build\windows 目录后重试
    echo   3. 检查 Visual Studio 安装是否完整
    goto :error_exit
)

if exist "%BUILD_DIR%\sec_chat.exe" (
    for %%F in ("%BUILD_DIR%\sec_chat.exe") do (
        echo   [OK] Windows Release 构建成功
        echo        文件: %BUILD_DIR%\sec_chat.exe
        echo        大小: %%~zF bytes
    )
) else (
    echo   [警告] 可执行文件未找到，检查其他名称...
    for %%f in ("%BUILD_DIR%\*.exe") do (
        echo        找到: %%~nxf
    )
)

echo.

REM ============================================================
REM 步骤 6: 复制本地 SQLite3 DLL（如果需要）
REM ============================================================

echo [步骤 6/7] 检查并复制 SQLite3 DLL...
echo.

call :copy_sqlite_dll

echo.

REM ============================================================
REM 步骤 7: 创建便携版 ZIP 包
REM ============================================================

if "%CREATE_ZIP%"=="1" (
    echo [步骤 7/7] 创建便携版 ZIP 包...
    echo.
    
    cd /d "%SCRIPT_DIR%"
    
    REM 创建输出目录
    if not exist "%OUTPUT_DIR%" mkdir "%OUTPUT_DIR%"
    
    set "ZIP_NAME=%APP_NAME%-Windows-Portable-%APP_VERSION%.zip"
    
    REM 删除旧的 ZIP 文件
    if exist "%OUTPUT_DIR%\!ZIP_NAME!" del /f "%OUTPUT_DIR%\!ZIP_NAME!"
    
    REM 使用 PowerShell 创建 ZIP
    powershell -Command "Compress-Archive -Path '%BUILD_DIR%\*' -DestinationPath '%OUTPUT_DIR%\!ZIP_NAME!' -Force"
    if !ERRORLEVEL! neq 0 (
        echo   [警告] ZIP 创建失败，请手动打包
    ) else (
        for %%F in ("%OUTPUT_DIR%\!ZIP_NAME!") do (
            echo   [OK] 便携版已创建
            echo        文件: %OUTPUT_DIR%\!ZIP_NAME!
            echo        大小: %%~zF bytes
        )
    )
    echo.
) else (
    echo [步骤 7/7] 跳过 ZIP 创建
    echo.
)

REM ============================================================
REM 构建完成
REM ============================================================

echo ============================================================
echo    Windows 客户端构建完成！
echo ============================================================
echo.
echo   构建产物位置:
echo   ------------------------------------------------------------
echo   可执行文件: %BUILD_DIR%\sec_chat.exe
if "%CREATE_ZIP%"=="1" (
    echo   便携版ZIP:  %OUTPUT_DIR%\%ZIP_NAME%
)
echo   ------------------------------------------------------------
echo.
echo   下一步:
echo   1. 直接运行: %BUILD_DIR%\sec_chat.exe
echo   2. 分发便携版 ZIP
echo   3. 使用 Inno Setup 创建安装包:
echo      iscc installer\windows\installer.iss
echo.

goto :end

REM ============================================================
REM 子程序: 设置 NuGet
REM ============================================================

:setup_nuget
where nuget >nul 2>&1
if %ERRORLEVEL% equ 0 (
    echo   [OK] NuGet 环境正常
    exit /b 0
)

set "NUGET_DIR=%LOCALAPPDATA%\NuGet"
set "NUGET_EXE=!NUGET_DIR!\nuget.exe"

if not exist "!NUGET_DIR!" mkdir "!NUGET_DIR!"

if exist "!NUGET_EXE!" (
    echo   [OK] NuGet 已缓存: !NUGET_EXE!
    set "PATH=!NUGET_DIR!;!PATH!"
    exit /b 0
)

if "%OFFLINE_MODE%"=="1" (
    echo   [警告] NuGet 未缓存 - 离线模式跳过下载
    exit /b 0
)

echo   下载 NuGet...
powershell -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri 'https://dist.nuget.org/win-x86-commandline/v6.0.0/nuget.exe' -OutFile '!NUGET_EXE!'" >nul 2>&1
if !ERRORLEVEL! equ 0 (
    echo   [OK] NuGet 已下载
    set "PATH=!NUGET_DIR!;!PATH!"
) else (
    echo   [警告] NuGet 下载失败
)
exit /b 0

REM ============================================================
REM 子程序: 检查 SQLite 缓存
REM ============================================================

:check_sqlite_cache
REM Flutter pub cache 路径
set "PUB_CACHE=%LOCALAPPDATA%\Pub\Cache"
if not exist "%PUB_CACHE%" (
    set "PUB_CACHE=%USERPROFILE%\.pub-cache"
)

REM 检查 sqlite3_flutter_libs 缓存
set "SQLITE_LIBS_CACHED=0"
for /d %%d in ("%PUB_CACHE%\hosted\pub.flutter-io.cn\sqlite3_flutter_libs-*") do (
    set "SQLITE_LIBS_CACHED=1"
    set "SQLITE_LIBS_PATH=%%d"
    echo   [OK] sqlite3_flutter_libs 已缓存: %%~nxd
)
for /d %%d in ("%PUB_CACHE%\hosted\pub.dev\sqlite3_flutter_libs-*") do (
    set "SQLITE_LIBS_CACHED=1"
    set "SQLITE_LIBS_PATH=%%d"
    echo   [OK] sqlite3_flutter_libs 已缓存: %%~nxd
)

if "%SQLITE_LIBS_CACHED%"=="0" (
    if "%OFFLINE_MODE%"=="1" (
        echo   [警告] sqlite3_flutter_libs 未缓存
    ) else (
        echo   [提示] sqlite3_flutter_libs 将在依赖获取时下载
    )
)

REM 检查本地 SQLite3 DLL
if exist "%SQLITE_CACHE_DIR%\windows\sqlite3.dll" (
    set "LOCAL_SQLITE_DLL=%SQLITE_CACHE_DIR%\windows\sqlite3.dll"
    echo   [OK] 本地 SQLite3 DLL 缓存: !LOCAL_SQLITE_DLL!
)

REM 检查 sqlite-dll.zip
if exist "%SQLITE_DLL_ZIP%" (
    echo   [OK] SQLite3 DLL ZIP 文件存在: %SQLITE_DLL_ZIP%
    
    REM 解压到缓存目录
    if not exist "%SQLITE_CACHE_DIR%\windows" mkdir "%SQLITE_CACHE_DIR%\windows"
    if not exist "%SQLITE_CACHE_DIR%\windows\sqlite3.dll" (
        echo   解压 SQLite3 DLL...
        powershell -Command "Expand-Archive -Path '%SQLITE_DLL_ZIP%' -DestinationPath '%SQLITE_CACHE_DIR%\windows' -Force" >nul 2>&1
        
        REM 查找并移动 DLL 文件
        for /r "%SQLITE_CACHE_DIR%\windows" %%f in (sqlite3.dll) do (
            if not "%%~dpf"=="%SQLITE_CACHE_DIR%\windows\" (
                copy "%%f" "%SQLITE_CACHE_DIR%\windows\sqlite3.dll" >nul 2>&1
            )
        )
        
        if exist "%SQLITE_CACHE_DIR%\windows\sqlite3.dll" (
            set "LOCAL_SQLITE_DLL=%SQLITE_CACHE_DIR%\windows\sqlite3.dll"
            echo   [OK] SQLite3 DLL 已解压
        )
    )
)

exit /b 0

REM ============================================================
REM 子程序: 复制 SQLite DLL
REM ============================================================

:copy_sqlite_dll
cd /d "%BUILD_DIR%"

REM 检查构建输出中是否已包含 sqlite3.dll
if exist "sqlite3.dll" (
    echo   [OK] sqlite3.dll 已包含在构建输出中
    exit /b 0
)

REM 从本地缓存复制
if defined LOCAL_SQLITE_DLL (
    if exist "!LOCAL_SQLITE_DLL!" (
        echo   复制本地缓存的 sqlite3.dll...
        copy "!LOCAL_SQLITE_DLL!" "%BUILD_DIR%\sqlite3.dll" >nul 2>&1
        if exist "%BUILD_DIR%\sqlite3.dll" (
            echo   [OK] sqlite3.dll 已从本地缓存复制
            exit /b 0
        )
    )
)

REM 从 sqlite3_flutter_libs 包中查找
if defined SQLITE_LIBS_PATH (
    for /r "!SQLITE_LIBS_PATH!" %%f in (sqlite3.dll) do (
        echo   复制 sqlite3.dll 从 sqlite3_flutter_libs...
        copy "%%f" "%BUILD_DIR%\sqlite3.dll" >nul 2>&1
        if exist "%BUILD_DIR%\sqlite3.dll" (
            echo   [OK] sqlite3.dll 已复制
            
            REM 同时备份到本地缓存
            if not exist "%SQLITE_CACHE_DIR%\windows" mkdir "%SQLITE_CACHE_DIR%\windows"
            copy "%%f" "%SQLITE_CACHE_DIR%\windows\sqlite3.dll" >nul 2>&1
            exit /b 0
        )
    )
)

echo   [提示] sqlite3.dll 通常由 Flutter 插件自动包含

REM 验证所有必需的 DLL
echo.
echo   验证依赖 DLL...
for %%d in (flutter_windows.dll) do (
    if exist "%BUILD_DIR%\%%d" (
        echo   [OK] %%d
    ) else (
        echo   [缺失] %%d
    )
)

exit /b 0

REM ============================================================
REM 帮助信息
REM ============================================================

:show_help
echo.
echo 使用方法: build-windows.bat [选项]
echo.
echo 选项:
echo   --offline    离线模式构建
echo                使用本地缓存的依赖，不下载任何文件
echo                适用于无网络环境或加速构建
echo.
echo   --clean      清理构建缓存后再构建
echo                解决 MSB8066 等构建错误
echo.
echo   --no-zip     不创建便携版 ZIP 包
echo.
echo   --help, -h   显示此帮助信息
echo.
echo 示例:
echo   build-windows.bat                # 正常构建
echo   build-windows.bat --offline      # 离线模式构建
echo   build-windows.bat --clean        # 清理后构建 - 解决构建错误
echo.
echo 常见问题:
echo   MSB8066 错误: 使用 --clean 参数进行完整清理后重试
echo.
goto :end

:error_exit
echo.
echo [错误] 构建失败，请检查上述错误信息
echo.
pause
exit /b 1

:end
endlocal
pause
