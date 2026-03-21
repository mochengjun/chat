@echo off
REM ============================================================
REM 版本管理脚本 (Windows 批处理版本)
REM 用于统一管理项目各组件的版本号
REM ============================================================

setlocal enabledelayedexpansion

REM 项目根目录
set PROJECT_ROOT=%~dp0..\..

REM 颜色代码
set "GREEN=[92m"
set "RED=[91m"
set "YELLOW=[93m"
set "BLUE=[94m"
set "NC=[0m"

REM 解析命令
set COMMAND=%~1
set COMMAND_ARG=%~2
set COMPONENT=all

REM 参数解析
:parse_args
if "%~1"=="" goto :execute
if /i "%~1"=="-h" goto :show_help
if /i "%~1"=="--help" goto :show_help
if /i "%~1"=="-c" (
    set COMPONENT=%~2
    shift
    shift
    goto :parse_args
)
if /i "%~1"=="--component" (
    set COMPONENT=%~2
    shift
    shift
    goto :parse_args
)
shift
goto :parse_args

:show_help
echo 用法: %~nx0 ^<命令^> [选项]
echo.
echo 命令:
echo   current           显示当前版本号
echo   bump ^<类型^>       递增版本号 (major^|minor^|patch)
echo   set ^<版本号^>      设置指定版本号
echo   sync              同步所有组件版本号
echo   validate          验证版本号一致性
echo.
echo 选项:
echo   -h, --help        显示帮助信息
echo   -c, --component   指定组件 (flutter^|web^|auth^|all)
echo.
echo 示例:
echo   %~nx0 current                # 显示当前版本
echo   %~nx0 bump minor             # 次版本号递增
echo   %~nx0 set 1.2.0              # 设置版本为 1.2.0
echo   %~nx0 bump patch -c flutter  # 仅更新 Flutter 版本
exit /b 0

:execute
REM 执行命令
if /i "%COMMAND%"=="current" goto :show_current
if /i "%COMMAND%"=="bump" goto :bump_version
if /i "%COMMAND%"=="set" goto :set_version
if /i "%COMMAND%"=="sync" goto :sync_versions
if /i "%COMMAND%"=="validate" goto :validate_versions
if "%COMMAND%"=="" goto :show_help
echo %RED%错误: 未知命令 '%COMMAND%'%NC%
goto :show_help

:show_current
echo.
echo %BLUE%========================================%NC%
echo %BLUE%当前版本信息%NC%
echo %BLUE%========================================%NC%
echo.

REM Flutter 版本
if exist "%PROJECT_ROOT%\apps\flutter_app\pubspec.yaml" (
    for /f "tokens=2 delims= " %%i in ('findstr /b "version:" "%PROJECT_ROOT%\apps\flutter_app\pubspec.yaml"') do (
        for /f "tokens=1 delims=+" %%j in ("%%i") do echo Flutter App:      %GREEN%%%j%NC%
    )
) else (
    echo Flutter App:      %YELLOW%未找到%NC%
)

REM Web 版本
if exist "%PROJECT_ROOT%\web-client\package.json" (
    for /f "tokens=2 delims=:, " %%i in ('findstr /c:"\"version\"" "%PROJECT_ROOT%\web-client\package.json"') do (
        set ver=%%i
        set ver=!ver:"=!
        echo Web Client:       %GREEN%!ver!%NC%
    )
) else (
    echo Web Client:       %YELLOW%未找到%NC%
)

REM Auth Service 版本
if exist "%PROJECT_ROOT%\services\auth-service\internal\version\version.go" (
    for /f "tokens=4 delims= " %%i in ('findstr /c:"Version" "%PROJECT_ROOT%\services\auth-service\internal\version\version.go"') do (
        set ver=%%i
        set ver=!ver:"=!
        echo Auth Service:     %GREEN%!ver!%NC%
    )
) else (
    echo Auth Service:     %YELLOW%未找到%NC%
)
echo.
exit /b 0

:bump_version
if "%COMMAND_ARG%"=="" (
    echo %RED%错误: 请指定递增类型 (major^|minor^|patch)%NC%
    exit /b 1
)
echo %BLUE%版本递增功能在 Windows 上建议使用 Git Bash 或 WSL 运行 Shell 脚本%NC%
echo 或手动更新以下文件:
echo   - apps\flutter_app\pubspec.yaml
echo   - web-client\package.json
echo   - services\auth-service\internal\version\version.go
exit /b 0

:set_version
if "%COMMAND_ARG%"=="" (
    echo %RED%错误: 请指定版本号%NC%
    exit /b 1
)
echo %BLUE%设置版本: %COMMAND_ARG%%NC%
echo 请手动更新版本号或使用 Git Bash 运行 Shell 脚本
exit /b 0

:sync_versions
echo %BLUE%建议使用 Git Bash 运行 sync 命令%NC%
exit /b 0

:validate_versions
echo %BLUE%建议使用 Git Bash 运行 validate 命令%NC%
exit /b 0
