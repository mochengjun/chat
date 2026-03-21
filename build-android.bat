@echo off
REM ============================================================
REM 企业安全聊天应用 - Android客户端构建脚本
REM 支持本地SQLite3库构建，避免网络下载依赖
REM 使用方法: build-android.bat [选项]
REM 选项:
REM   --offline    离线模式构建（使用本地缓存）
REM   --clean      清理构建缓存
REM   --release    仅构建Release版本
REM   --debug      仅构建Debug版本
REM ============================================================

REM 强制设置 JAVA_HOME 为 JDK 17 (Flutter Android 构建需要)
set "JAVA_HOME=C:\Program Files\Eclipse Adoptium\jdk-17.0.18.8-hotspot"
set "PATH=%JAVA_HOME%\bin;%PATH%"

setlocal EnableDelayedExpansion

echo.
echo ============================================================
echo    企业安全聊天应用 - Android客户端构建
echo    版本: 1.0.0
echo ============================================================
echo.

REM 保存脚本所在目录
set "SCRIPT_DIR=%~dp0"
cd /d "%SCRIPT_DIR%"

REM 设置默认变量
set "OFFLINE_MODE=0"
set "CLEAN_BUILD=0"
set "BUILD_DEBUG=1"
set "BUILD_RELEASE=1"
set "FLUTTER_APP_DIR=%SCRIPT_DIR%apps\flutter_app"
set "SQLITE_CACHE_DIR=%SCRIPT_DIR%sqlite-cache"
set "OUTPUT_DIR=%SCRIPT_DIR%installer\android"
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
if /i "%~1"=="--release" (
    set "BUILD_DEBUG=0"
    set "BUILD_RELEASE=1"
    shift
    goto :parse_args
)
if /i "%~1"=="--debug" (
    set "BUILD_DEBUG=1"
    set "BUILD_RELEASE=0"
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

REM 检查 Java 环境
echo   检查 Java 环境: %JAVA_HOME%
if exist "%JAVA_HOME%\bin\java.exe" (
    echo   [OK] Java 环境正常
    set "PATH=%JAVA_HOME%\bin;%PATH%"
) else (
    where java >nul 2>&1
    if !ERRORLEVEL! neq 0 (
        echo [错误] Java 未安装或未添加到 PATH
        echo        请安装 JDK 11 或更高版本
        echo        当前 JAVA_HOME: %JAVA_HOME%
        goto :error_exit
    )
    echo   [OK] Java 环境正常
)

REM 检查 Android SDK
if not defined ANDROID_HOME (
    if not defined ANDROID_SDK_ROOT (
        echo   [警告] ANDROID_HOME/ANDROID_SDK_ROOT 未设置
        echo          Flutter 可能无法找到 Android SDK
    ) else (
        echo   [OK] Android SDK: %ANDROID_SDK_ROOT%
    )
) else (
    echo   [OK] Android SDK: %ANDROID_HOME%
)

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
REM 步骤 2: 检查本地SQLite3库缓存
REM ============================================================

echo [步骤 2/7] 检查本地SQLite3库缓存...
echo.

call :check_sqlite_cache

echo.

REM ============================================================
REM 步骤 3: 清理旧构建（可选）
REM ============================================================

cd /d "%FLUTTER_APP_DIR%"

if "%CLEAN_BUILD%"=="1" (
    echo [步骤 3/7] 清理旧构建...
    echo.
    
    REM 先清理锁文件
    call :cleanup_lock_files
    
    echo   清理 Flutter 构建缓存...
    call flutter clean
    if !ERRORLEVEL! neq 0 (
        echo   [警告] Flutter clean 失败，继续构建...
    ) else (
        echo   [OK] 构建缓存已清理
    )
    echo.
) else (
    echo [步骤 3/7] 清理锁文件...
    echo.
    
    REM 清理锁文件
    call :cleanup_lock_files
    
    echo   [OK] 锁文件检查完成
    echo.
)

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
        echo   3. 使用离线模式: build-android.bat --offline
        goto :error_exit
    )
    echo   [OK] 使用离线缓存完成依赖获取
)

:pub_get_done
echo.

REM ============================================================
REM 步骤 5: 构建 Debug APK
REM ============================================================

if "%BUILD_DEBUG%"=="1" (
    echo [步骤 5/7] 构建 Debug APK...
    echo.
    
    cd /d "%FLUTTER_APP_DIR%"
    
    call flutter build apk --debug
    if !ERRORLEVEL! neq 0 (
        echo [错误] Debug APK 构建失败
        goto :error_exit
    )
    
    set "APK_DEBUG=build\app\outputs\flutter-apk\app-debug.apk"
    if exist "!APK_DEBUG!" (
        for %%F in ("!APK_DEBUG!") do (
            echo   [OK] Debug APK 构建成功
            echo        文件: !APK_DEBUG!
            echo        大小: %%~zF bytes
        )
    ) else (
        echo   [警告] Debug APK 文件未找到
    )
    echo.
) else (
    echo [步骤 5/7] 跳过 Debug APK 构建
    echo.
)

REM ============================================================
REM 步骤 6: 构建 Release APK 和 App Bundle
REM ============================================================

if "%BUILD_RELEASE%"=="1" (
    echo [步骤 6/7] 构建 Release APK...
    echo.
    
    cd /d "%FLUTTER_APP_DIR%"
    
    REM 构建 Release APK
    call flutter build apk --release
    if !ERRORLEVEL! neq 0 (
        echo [错误] Release APK 构建失败
        goto :error_exit
    )
    
    set "APK_RELEASE=build\app\outputs\flutter-apk\app-release.apk"
    if exist "!APK_RELEASE!" (
        for %%F in ("!APK_RELEASE!") do (
            echo   [OK] Release APK 构建成功
            echo        文件: !APK_RELEASE!
            echo        大小: %%~zF bytes
        )
    )
    
    echo.
    echo   构建 App Bundle...
    
    REM 构建 App Bundle
    call flutter build appbundle --release
    if !ERRORLEVEL! neq 0 (
        echo   [警告] App Bundle 构建失败
    ) else (
        set "AAB_RELEASE=build\app\outputs\bundle\release\app-release.aab"
        if exist "!AAB_RELEASE!" (
            for %%F in ("!AAB_RELEASE!") do (
                echo   [OK] App Bundle 构建成功
                echo        文件: !AAB_RELEASE!
                echo        大小: %%~zF bytes
            )
        )
    )
    echo.
) else (
    echo [步骤 6/7] 跳过 Release 构建
    echo.
)

REM ============================================================
REM 步骤 7: 验证构建结果
REM ============================================================

echo [步骤 7/7] 验证构建结果...
echo.

cd /d "%FLUTTER_APP_DIR%"

REM 验证 SQLite 相关库
echo   验证 SQLite 库集成...

REM 检查 APK 中是否包含 SQLite 库
if exist "build\app\intermediates\merged_native_libs\release\out\lib\arm64-v8a\libsqlite3.so" (
    echo   [OK] SQLite3 库已集成 - arm64-v8a
)
if exist "build\app\intermediates\merged_native_libs\debug\out\lib\arm64-v8a\libsqlite3.so" (
    echo   [OK] SQLite3 库已集成 - arm64-v8a debug
)
if exist "build\app\intermediates\merged_native_libs\release\out\lib\armeabi-v7a\libsqlite3.so" (
    echo   [OK] SQLite3 库已集成 - armeabi-v7a
)

REM 备份 SQLite3 库到本地缓存（供离线使用）
if not exist "%SQLITE_CACHE_DIR%\android" mkdir "%SQLITE_CACHE_DIR%\android" 2>nul
if exist "build\app\intermediates\merged_native_libs\release\out\lib" (
    xcopy /E /Y /Q "build\app\intermediates\merged_native_libs\release\out\lib" "%SQLITE_CACHE_DIR%\android\" >nul 2>&1
    if !ERRORLEVEL! equ 0 (
        echo   [OK] SQLite3 库已备份到本地缓存
    )
)

echo.

REM ============================================================
REM 复制构建产物到输出目录
REM ============================================================

echo [步骤 8/8] 复制构建产物到输出目录...
echo.

REM 创建输出目录
if not exist "%OUTPUT_DIR%" mkdir "%OUTPUT_DIR%"

cd /d "%FLUTTER_APP_DIR%"

REM 复制 Debug APK
if "%BUILD_DEBUG%"=="1" (
    if exist "build\app\outputs\flutter-apk\app-debug.apk" (
        copy /Y "build\app\outputs\flutter-apk\app-debug.apk" "%OUTPUT_DIR%\SecChat-debug.apk" >nul
        if exist "%OUTPUT_DIR%\SecChat-debug.apk" (
            echo   [OK] Debug APK 已复制到: %OUTPUT_DIR%\SecChat-debug.apk
        )
    )
)

REM 复制 Release APK 和 AAB
if "%BUILD_RELEASE%"=="1" (
    if exist "build\app\outputs\flutter-apk\app-release.apk" (
        copy /Y "build\app\outputs\flutter-apk\app-release.apk" "%OUTPUT_DIR%\SecChat-release.apk" >nul
        if exist "%OUTPUT_DIR%\SecChat-release.apk" (
            echo   [OK] Release APK 已复制到: %OUTPUT_DIR%\SecChat-release.apk
        )
    )
    if exist "build\app\outputs\bundle\release\app-release.aab" (
        copy /Y "build\app\outputs\bundle\release\app-release.aab" "%OUTPUT_DIR%\SecChat-release.aab" >nul
        if exist "%OUTPUT_DIR%\SecChat-release.aab" (
            echo   [OK] App Bundle 已复制到: %OUTPUT_DIR%\SecChat-release.aab
        )
    )
)

echo.

REM ============================================================
REM 构建完成
REM ============================================================

echo ============================================================
echo    Android 客户端构建完成！
echo ============================================================
echo.
echo   输出目录: %OUTPUT_DIR%
echo   ------------------------------------------------------------
if "%BUILD_DEBUG%"=="1" (
echo   Debug APK:    %OUTPUT_DIR%\SecChat-debug.apk
)
if "%BUILD_RELEASE%"=="1" (
echo   Release APK:  %OUTPUT_DIR%\SecChat-release.apk
echo   App Bundle:   %OUTPUT_DIR%\SecChat-release.aab
)
echo   ------------------------------------------------------------
echo.
echo   下一步:
echo   1. 安装 APK 测试: adb install %OUTPUT_DIR%\SecChat-release.apk
echo   2. 上传 AAB 到 Google Play Console
echo.

goto :end

REM ============================================================
REM 子程序: 清理锁文件
REM ============================================================

:cleanup_lock_files
REM 终止可能占用锁文件的进程
echo   检查并终止占用锁文件的进程...
taskkill /f /im "dart.exe" >nul 2>&1
taskkill /f /im "flutter.exe" >nul 2>&1

REM 等待进程完全终止
timeout /t 2 /nobreak >nul

REM 清理 hooks_runner 目录（包含锁文件）
if exist ".dart_tool\hooks_runner" (
    echo   清理 hooks_runner 目录...
    rmdir /s /q ".dart_tool\hooks_runner" 2>nul
    if !ERRORLEVEL! equ 0 (
        echo   [OK] hooks_runner 目录已清理
    ) else (
        echo   [警告] hooks_runner 目录清理失败，尝试单独删除锁文件...
        del /f /q ".dart_tool\hooks_runner\shared\sqlite3\.lock" 2>nul
        del /f /q ".dart_tool\hooks_runner\shared\sqlite3\*.lock" 2>nul
    )
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
    echo   [OK] sqlite3_flutter_libs 已缓存: %%~nxd
)
for /d %%d in ("%PUB_CACHE%\hosted\pub.dev\sqlite3_flutter_libs-*") do (
    set "SQLITE_LIBS_CACHED=1"
    echo   [OK] sqlite3_flutter_libs 已缓存: %%~nxd
)

if "%SQLITE_LIBS_CACHED%"=="0" (
    if "%OFFLINE_MODE%"=="1" (
        echo   [警告] sqlite3_flutter_libs 未缓存，离线模式可能失败
    ) else (
        echo   [提示] sqlite3_flutter_libs 将在依赖获取时下载
    )
) 

REM 检查 sqflite 缓存
set "SQFLITE_CACHED=0"
for /d %%d in ("%PUB_CACHE%\hosted\pub.flutter-io.cn\sqflite-*") do (
    set "SQFLITE_CACHED=1"
)
for /d %%d in ("%PUB_CACHE%\hosted\pub.dev\sqflite-*") do (
    set "SQFLITE_CACHED=1"
)

if "%SQFLITE_CACHED%"=="1" (
    echo   [OK] sqflite 已缓存
) else (
    if "%OFFLINE_MODE%"=="1" (
        echo   [警告] sqflite 未缓存
    )
)

REM 检查本地 SQLite3 备份
if exist "%SQLITE_CACHE_DIR%\android" (
    echo   [OK] 本地 SQLite3 Android 库备份存在
)

exit /b 0

REM ============================================================
REM 帮助信息
REM ============================================================

:show_help
echo.
echo 使用方法: build-android.bat [选项]
echo.
echo 选项:
echo   --offline    离线模式构建
echo                使用本地缓存的依赖，不下载任何文件
echo                适用于无网络环境或加速构建
echo.
echo   --clean      清理构建缓存后再构建
echo.
echo   --release    仅构建 Release 版本
echo.
echo   --debug      仅构建 Debug 版本
echo.
echo   --help, -h   显示此帮助信息
echo.
echo 示例:
echo   build-android.bat                    # 构建 Debug 和 Release
echo   build-android.bat --offline          # 离线模式构建
echo   build-android.bat --clean --release  # 清理后仅构建 Release
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
