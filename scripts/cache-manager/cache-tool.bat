@echo off
REM ============================================================
REM 智能编译缓存工具 - Windows 批处理包装器
REM 使用方法: cache-tool.bat <command> [options]
REM ============================================================

setlocal EnableDelayedExpansion

set "SCRIPT_DIR=%~dp0"
set "PYTHON_SCRIPT=%SCRIPT_DIR%cache_manager.py"

REM 检查 Python 是否安装
where python >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo [错误] Python 未安装或未添加到 PATH
    echo        请安装 Python 3.7 或更高版本
    goto :error_exit
)

REM 检查脚本是否存在
if not exist "%PYTHON_SCRIPT%" (
    echo [错误] 未找到 cache_manager.py
    echo        路径: %PYTHON_SCRIPT%
    goto :error_exit
)

REM 执行 Python 脚本,传递所有参数
python "%PYTHON_SCRIPT%" %*

if %ERRORLEVEL% equ 0 (
    goto :end
) else (
    goto :error_exit
)

:error_exit
exit /b 1

:end
endlocal
