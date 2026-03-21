@echo off
REM ============================================================
REM 双仓库同步推送脚本 (Windows 批处理版本)
REM 用于同步推送代码到 GitHub 和 Gitee
REM ============================================================

setlocal enabledelayedexpansion

REM 默认配置
set GITHUB_REMOTE=origin
set GITEE_REMOTE=gitee
set GITHUB_REPO=mochengjun/sec-chat
set GITEE_REPO=mochengjun/sec-chat

REM 颜色代码 (Windows 10+)
set "GREEN=[92m"
set "RED=[91m"
set "YELLOW=[93m"
set "BLUE=[94m"
set "NC=[0m"

REM 参数解析
set BRANCH=
set SYNC_TAGS=0
set SYNC_ALL=0
set SETUP_MODE=0
set DRY_RUN=0

:parse_args
if "%~1"=="" goto :main
if /i "%~1"=="-h" goto :show_help
if /i "%~1"=="--help" goto :show_help
if /i "%~1"=="-b" (
    set BRANCH=%~2
    shift
    shift
    goto :parse_args
)
if /i "%~1"=="--branch" (
    set BRANCH=%~2
    shift
    shift
    goto :parse_args
)
if /i "%~1"=="-t" (
    set SYNC_TAGS=1
    shift
    goto :parse_args
)
if /i "%~1"=="--tags" (
    set SYNC_TAGS=1
    shift
    goto :parse_args
)
if /i "%~1"=="-a" (
    set SYNC_ALL=1
    shift
    goto :parse_args
)
if /i "%~1"=="--all" (
    set SYNC_ALL=1
    shift
    goto :parse_args
)
if /i "%~1"=="-s" (
    set SETUP_MODE=1
    shift
    goto :parse_args
)
if /i "%~1"=="--setup" (
    set SETUP_MODE=1
    shift
    goto :parse_args
)
if /i "%~1"=="--dry-run" (
    set DRY_RUN=1
    shift
    goto :parse_args
)
set BRANCH=%~1
shift
goto :parse_args

:show_help
echo 用法: %~nx0 [选项] [分支名]
echo.
echo 选项:
echo   -h, --help          显示帮助信息
echo   -b, --branch        指定要同步的分支 (默认: 当前分支)
echo   -t, --tags          同步所有标签
echo   -a, --all           同步所有分支和标签
echo   -s, --setup         配置双仓库远程地址
echo   --dry-run           仅显示将要执行的操作，不实际执行
echo.
echo 示例:
echo   %~nx0                  # 同步当前分支到两个仓库
echo   %~nx0 -b main          # 同步 main 分支
echo   %~nx0 -t               # 同步所有标签
echo   %~nx0 -a               # 同步所有分支和标签
echo   %~nx0 -s               # 配置双仓库远程地址
echo.
echo 远程仓库:
echo   GitHub: https://github.com/%GITHUB_REPO%
echo   Gitee:  https://gitee.com/%GITEE_REPO%
exit /b 0

:main
echo.
echo %BLUE%========================================%NC%
echo %BLUE%双仓库同步工具 (Windows)%NC%
echo %BLUE%========================================%NC%
echo.

REM 检查 Git
where git >nul 2>&1
if errorlevel 1 (
    echo %RED%错误: 未找到 Git，请先安装 Git%NC%
    exit /b 1
)

REM 检查是否在 Git 仓库中
git rev-parse --is-inside-work-tree >nul 2>&1
if errorlevel 1 (
    echo %RED%错误: 当前目录不是 Git 仓库%NC%
    exit /b 1
)

REM 配置模式
if %SETUP_MODE%==1 (
    call :setup_remotes
    exit /b 0
)

REM 检查远程仓库
call :check_remote %GITHUB_REMOTE%
if errorlevel 1 (
    echo %YELLOW%请先运行 '%~nx0 -s' 配置远程仓库%NC%
    exit /b 1
)

call :check_remote %GITEE_REMOTE%
if errorlevel 1 (
    echo %YELLOW%请先运行 '%~nx0 -s' 配置远程仓库%NC%
    exit /b 1
)

REM 获取当前分支
if "%BRANCH%"=="" (
    for /f "tokens=*" %%i in ('git branch --show-current 2^>nul') do set BRANCH=%%i
    echo %BLUE%当前分支: %BRANCH%%NC%
)

set SUCCESS_COUNT=0
set FAIL_COUNT=0

REM 同步到 GitHub
echo.
echo %YELLOW%>>> GitHub (%GITHUB_REMOTE%)%NC%
if %SYNC_ALL%==1 (
    call :push_all_branches %GITHUB_REMOTE%
) else (
    call :push_branch %GITHUB_REMOTE% %BRANCH%
)
if errorlevel 1 (
    set /a FAIL_COUNT+=1
) else (
    set /a SUCCESS_COUNT+=1
)

if %SYNC_TAGS%==1 (
    call :push_tags %GITHUB_REMOTE%
)

REM 同步到 Gitee
echo.
echo %YELLOW%>>> Gitee (%GITEE_REMOTE%)%NC%
if %SYNC_ALL%==1 (
    call :push_all_branches %GITEE_REMOTE%
) else (
    call :push_branch %GITEE_REMOTE% %BRANCH%
)
if errorlevel 1 (
    set /a FAIL_COUNT+=1
) else (
    set /a SUCCESS_COUNT+=1
)

if %SYNC_TAGS%==1 (
    call :push_tags %GITEE_REMOTE%
)

REM 显示结果
echo.
echo %BLUE%========================================%NC%
echo %BLUE%同步结果%NC%
echo %BLUE%========================================%NC%

if %FAIL_COUNT%==0 (
    echo %GREEN%✓ 同步成功！%NC%
) else (
    echo %YELLOW%! 同步完成，但有 %FAIL_COUNT% 个操作失败%NC%
)

echo.
echo 仓库地址:
echo   GitHub: https://github.com/%GITHUB_REPO%
echo   Gitee:  https://gitee.com/%GITEE_REPO%
echo.

exit /b 0

REM ============================================================
REM 函数定义
REM ============================================================

:setup_remotes
echo %BLUE%配置双仓库远程地址...%NC%

REM 检查 GitHub 远程
git remote | findstr /x "%GITHUB_REMOTE%" >nul 2>&1
if errorlevel 1 (
    echo 添加 GitHub 远程仓库...
    git remote add %GITHUB_REMOTE% https://github.com/%GITHUB_REPO%.git
) else (
    echo %GREEN%GitHub 远程仓库已配置%NC%
)

REM 检查 Gitee 远程
git remote | findstr /x "%GITEE_REMOTE%" >nul 2>&1
if errorlevel 1 (
    echo 添加 Gitee 远程仓库...
    git remote add %GITEE_REMOTE% https://gitee.com/%GITEE_REPO%.git
) else (
    echo %GREEN%Gitee 远程仓库已配置%NC%
)

echo.
echo %GREEN%远程仓库配置完成:%NC%
git remote -v
exit /b 0

:check_remote
git remote | findstr /x "%~1" >nul 2>&1
if errorlevel 1 (
    echo %YELLOW%警告: 远程仓库 '%~1' 不存在%NC%
    exit /b 1
)
exit /b 0

:push_branch
setlocal
set REMOTE=%~1
set BRANCH_NAME=%~2

echo %BLUE%推送分支 '%BRANCH_NAME%' 到 %REMOTE%...%NC%

if %DRY_RUN%==1 (
    echo [DRY-RUN] git push %REMOTE% %BRANCH_NAME%
) else (
    git push %REMOTE% %BRANCH_NAME%
    if errorlevel 1 (
        echo %RED%✗ 推送到 %REMOTE%/%BRANCH_NAME% 失败%NC%
        exit /b 1
    )
    echo %GREEN%✓ 成功推送到 %REMOTE%/%BRANCH_NAME%%NC%
)
exit /b 0

:push_tags
setlocal
set REMOTE=%~1

echo %BLUE%推送所有标签到 %REMOTE%...%NC%

if %DRY_RUN%==1 (
    echo [DRY-RUN] git push %REMOTE% --tags
) else (
    git push %REMOTE% --tags
    if errorlevel 1 (
        echo %YELLOW%! 推送标签到 %REMOTE% 时出现警告%NC%
    ) else (
        echo %GREEN%✓ 成功推送标签到 %REMOTE%%NC%
    )
)
exit /b 0

:push_all_branches
setlocal
set REMOTE=%~1

echo %BLUE%推送所有分支到 %REMOTE%...%NC%

if %DRY_RUN%==1 (
    echo [DRY-RUN] git push %REMOTE% --all
) else (
    git push %REMOTE% --all
    if errorlevel 1 (
        echo %RED%✗ 推送所有分支到 %REMOTE% 失败%NC%
        exit /b 1
    )
    echo %GREEN%✓ 成功推送所有分支到 %REMOTE%%NC%
)
exit /b 0
