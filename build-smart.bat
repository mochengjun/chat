@echo off
chcp 65001 >nul
REM ============================================================
REM 智能构建脚本 - 集成缓存管理
REM 使用方法: build-smart.bat [选项]
REM 选项:
REM   --offline       离线模式构建(使用本地缓存)
REM   --cache-first   优先从缓存同步依赖
REM   --clean-cache   清理缓存后再构建
REM   --project       指定项目类型 (flutter/go/nodejs/all)
REM ============================================================

REM 强制设置 JAVA_HOME 为 JDK 17 (Flutter Android 构建需要)
set "JAVA_HOME=C:\Program Files\Eclipse Adoptium\jdk-17.0.18.8-hotspot"
set "PATH=%JAVA_HOME%\bin;%PATH%"

setlocal EnableDelayedExpansion

echo.
echo ============================================================
echo    智能构建系统 - 集成缓存管理
echo    版本: 1.0.0
echo ============================================================
echo.

REM 保存脚本所在目录
set "SCRIPT_DIR=%~dp0"
REM 确保目录路径以反斜杠结尾
if "!SCRIPT_DIR:~-1!" neq "\" set "SCRIPT_DIR=%SCRIPT_DIR%\"
cd /d "%SCRIPT_DIR%"

REM 设置项目根目录（与脚本目录相同）
set "PROJECT_ROOT=%SCRIPT_DIR%"

REM 设置默认变量
set "OFFLINE_MODE=0"
set "CACHE_FIRST=0"
set "CLEAN_CACHE=0"
set "PROJECT_TYPE=all"

REM 解析命令行参数
:parse_args
if "%~1"=="" goto :args_done
if /i "%~1"=="--offline" (
    set "OFFLINE_MODE=1"
    shift
    goto :parse_args
)
if /i "%~1"=="--cache-first" (
    set "CACHE_FIRST=1"
    shift
    goto :parse_args
)
if /i "%~1"=="--clean-cache" (
    set "CLEAN_CACHE=1"
    shift
    goto :parse_args
)
if /i "%~1"=="--project" (
    set "PROJECT_TYPE=%~2"
    shift
    shift
    goto :parse_args
)
shift
goto :parse_args

:args_done

echo [配置]
echo   离线模式: %OFFLINE_MODE%
echo   缓存优先: %CACHE_FIRST%
echo   清理缓存: %CLEAN_CACHE%
echo   项目类型: %PROJECT_TYPE%
echo.

REM ============================================================
REM 步骤 1: 检查缓存工具
REM ============================================================

echo [步骤 1/4] 检查缓存工具...
echo.

set "CACHE_TOOL=%SCRIPT_DIR%scripts\cache-manager\cache-tool.bat"

if not exist "%CACHE_TOOL%" (
    echo [警告] 未找到缓存工具: %CACHE_TOOL%
    echo        将使用传统构建流程
    goto :traditional_build
)

echo [OK] 缓存工具就绪
echo.

REM ============================================================
REM 步骤 2: 清理缓存 (可选)
REM ============================================================

if "%CLEAN_CACHE%"=="1" (
    echo [步骤 2/4] 清理缓存...
    echo.
    
    call "%CACHE_TOOL%" clean --project %PROJECT_TYPE%
    if !ERRORLEVEL! neq 0 (
        echo [警告] 缓存清理失败,继续构建...
    )
    echo.
) else (
    echo [步骤 2/4] 跳过缓存清理
    echo.
)

REM ============================================================
REM 步骤 3: 同步依赖到缓存
REM ============================================================

echo [步骤 3/4] 同步依赖...
echo.

if "%CACHE_FIRST%"=="1" (
    echo 使用缓存优先模式...
    
    if "%OFFLINE_MODE%"=="1" (
        call "%CACHE_TOOL%" sync --project %PROJECT_TYPE% --offline
    ) else (
        call "%CACHE_TOOL%" sync --project %PROJECT_TYPE%
    )
    
    if !ERRORLEVEL! neq 0 (
        echo [警告] 缓存同步失败,将在线下载依赖
    )
) else (
    echo 检查缓存状态...
    call "%CACHE_TOOL%" check --project %PROJECT_TYPE%
)

echo.

REM 返回项目根目录（缓存工具可能改变了目录）
cd /d "%PROJECT_ROOT%"

REM ============================================================
REM 步骤 4: 执行构建
REM ============================================================

echo [步骤 4/4] 执行构建...
echo.

:traditional_build

REM 根据项目类型调用相应的构建脚本

if "%PROJECT_TYPE%"=="flutter" (
    echo 构建 Flutter 项目...
    if "%OFFLINE_MODE%"=="1" (
        call "%SCRIPT_DIR%build-android.bat" --offline
    ) else (
        call "%SCRIPT_DIR%build-android.bat"
    )
    goto :build_done
)

if "%PROJECT_TYPE%"=="go" (
    echo 构建 Go 服务...
    call "%SCRIPT_DIR%build-services.bat" --pure-go
    goto :build_done
)

if "%PROJECT_TYPE%"=="nodejs" (
    echo 构建 Node.js 项目...
    cd /d "%SCRIPT_DIR%\web-client"
    if "%OFFLINE_MODE%"=="1" (
        call npm install --offline
    ) else (
        call npm install
    )
    call npm run build
    goto :build_done
)

if "%PROJECT_TYPE%"=="all" (
    echo 构建所有项目...
    echo.
    
    REM 构建 Go 服务
    echo [1/3] 构建 Go 服务...
    call "%SCRIPT_DIR%build-services.bat" --pure-go --all
    if !ERRORLEVEL! neq 0 (
        echo [警告] Go 服务构建失败
    )
    echo.
    
    REM 构建 Flutter Android
    echo [2/3] 构建 Flutter Android...
    if "%OFFLINE_MODE%"=="1" (
        call "%SCRIPT_DIR%build-android.bat" --offline
    ) else (
        call "%SCRIPT_DIR%build-android.bat"
    )
    if !ERRORLEVEL! neq 0 (
        echo [警告] Flutter 构建失败
    )
    echo.
    
    REM 构建 Web 客户端
    echo [3/3] 构建 Web 客户端...
    cd /d "%SCRIPT_DIR%\web-client"
    if "%OFFLINE_MODE%"=="1" (
        call npm install --offline --prefer-offline
    ) else (
        call npm install
    )
    call npm run build
    if !ERRORLEVEL! neq 0 (
        echo [警告] Web 客户端构建失败
    )
    echo.
)

:build_done

echo.
echo ============================================================
echo    构建完成！
echo ============================================================
echo.

REM 显示缓存统计
if exist "%CACHE_TOOL%" (
    echo 缓存统计信息:
    call "%CACHE_TOOL%" stats
)

goto :end

:error_exit
echo.
echo [错误] 构建失败
exit /b 1

:end
endlocal
pause
