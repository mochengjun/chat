@echo off
REM ============================================================
REM Secure Enterprise Chat - 后端服务构建脚本
REM 支持使用本地SQLite3库构建，避免网络下载依赖
REM 使用方法: build-services.bat [选项]
REM 选项:
REM   --cgo        使用CGO模式（需要本地SQLite3库）
REM   --pure-go    使用纯Go模式（默认，无需外部依赖）
REM   --clean      清理构建缓存
REM   --all        构建所有服务
REM ============================================================

setlocal EnableDelayedExpansion

echo.
echo ============================================================
echo    Secure Enterprise Chat - 后端服务构建脚本
echo    版本: 1.0.0
echo ============================================================
echo.

REM 保存脚本所在目录
set "SCRIPT_DIR=%~dp0"
cd /d "%SCRIPT_DIR%"

REM 设置默认变量
set "BUILD_MODE=pure-go"
set "CLEAN_BUILD=0"
set "BUILD_ALL=0"
set "SQLITE_DLL_ZIP=%SCRIPT_DIR%sqlite-dll.zip"
set "SQLITE_DLL_DIR=%SCRIPT_DIR%sqlite-lib"
set "AUTH_SERVICE_DIR=%SCRIPT_DIR%services\auth-service"

REM 解析命令行参数
:parse_args
if "%~1"=="" goto :args_done
if /i "%~1"=="--cgo" (
    set "BUILD_MODE=cgo"
    shift
    goto :parse_args
)
if /i "%~1"=="--pure-go" (
    set "BUILD_MODE=pure-go"
    shift
    goto :parse_args
)
if /i "%~1"=="--clean" (
    set "CLEAN_BUILD=1"
    shift
    goto :parse_args
)
if /i "%~1"=="--all" (
    set "BUILD_ALL=1"
    shift
    goto :parse_args
)
if /i "%~1"=="--help" goto :show_help
if /i "%~1"=="-h" goto :show_help
shift
goto :parse_args

:args_done

echo [配置] 构建模式: %BUILD_MODE%
echo.

REM ============================================================
REM 步骤 1: 环境检查
REM ============================================================

echo [步骤 1/6] 环境检查...
echo.

REM 检查 Go 环境
where go >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo [错误] Go 未安装或未添加到 PATH
    echo        请访问 https://golang.org/dl/ 下载安装
    goto :error_exit
)
for /f "tokens=3" %%v in ('go version 2^>nul') do set GO_VERSION=%%v
echo   [OK] Go 环境: %GO_VERSION%

REM 检查 Git 环境（用于Go模块下载）
where git >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo   [警告] Git 未安装，可能影响依赖下载
) else (
    echo   [OK] Git 环境正常
)

REM 如果是CGO模式，检查C编译器
if "%BUILD_MODE%"=="cgo" (
    call :check_c_compiler
)

echo.

REM ============================================================
REM 步骤 2: 检查本地SQLite3库文件
REM ============================================================

echo [步骤 2/6] 检查本地SQLite3库文件...
echo.

if "%BUILD_MODE%"=="cgo" (
    call :setup_cgo_sqlite
    if !ERRORLEVEL! neq 0 goto :error_exit
) else (
    REM 纯Go模式，禁用CGO
    set "CGO_ENABLED=0"
    echo   [OK] 使用纯Go模式构建 - CGO_ENABLED=0
    echo        使用 glebarez/sqlite 驱动，无需外部SQLite3库
)

echo.

REM ============================================================
REM 步骤 3: 清理构建缓存（可选）
REM ============================================================

if "%CLEAN_BUILD%"=="1" (
    echo [步骤 3/6] 清理构建缓存...
    echo.
    
    cd /d "%AUTH_SERVICE_DIR%"
    
    REM 清理Go模块缓存
    echo   清理 Go 构建缓存...
    go clean -cache
    
    REM 删除旧的可执行文件
    if exist "auth-service.exe" del /f "auth-service.exe"
    if exist "auth-service" del /f "auth-service"
    
    echo   [OK] 构建缓存已清理
    echo.
) else (
    echo [步骤 3/6] 跳过清理 - 使用 --clean 强制清理
    echo.
)

REM ============================================================
REM 步骤 4: 下载依赖
REM ============================================================

echo [步骤 4/6] 下载依赖...
echo.

cd /d "%AUTH_SERVICE_DIR%"

REM 清除可能干扰的代理环境变量
set "http_proxy="
set "https_proxy="
set "HTTP_PROXY="
set "HTTPS_PROXY="

REM 设置Go代理（国内镜像）
set "GOPROXY=https://goproxy.cn,https://goproxy.io,direct"
echo   使用 Go 代理: %GOPROXY%

REM 下载依赖（带重试机制）
set RETRY_COUNT=0
set MAX_RETRIES=3

:retry_mod_download
set /a RETRY_COUNT+=1
echo   下载依赖（第 !RETRY_COUNT!/%MAX_RETRIES% 次尝试）...

go mod download
if !ERRORLEVEL! equ 0 (
    echo   [OK] 依赖下载成功
    goto :mod_download_done
)

if !RETRY_COUNT! lss %MAX_RETRIES% (
    echo   [警告] 依赖下载失败，等待5秒后重试...
    timeout /t 5 /nobreak >nul
    goto :retry_mod_download
)

echo [警告] 依赖下载失败，尝试使用本地缓存继续构建...

:mod_download_done
echo.

REM ============================================================
REM 步骤 5: 构建服务
REM ============================================================

echo [步骤 5/6] 构建服务...
echo.

cd /d "%AUTH_SERVICE_DIR%"

REM 获取版本信息
set "BUILD_VERSION=1.0.0"

REM 设置构建标志（简化，避免空格问题）
set "LDFLAGS=-s -w"

echo   构建目标: auth-service.exe
echo   构建模式: %BUILD_MODE%
echo   CGO_ENABLED: %CGO_ENABLED%
echo.

REM 执行构建
echo   正在编译...
go build -ldflags "%LDFLAGS%" -o auth-service.exe ./cmd/main.go

if %ERRORLEVEL% neq 0 (
    echo [错误] 构建失败
    echo.
    echo 可能的解决方案:
    if "%BUILD_MODE%"=="cgo" (
        echo   1. 确保C编译器已正确安装
        echo   2. 确保SQLite3头文件和库文件路径正确
        echo   3. 尝试使用纯Go模式: build-services.bat --pure-go
    ) else (
        echo   1. 检查Go版本兼容性
        echo   2. 运行 go mod tidy 修复依赖
        echo   3. 检查源码是否有语法错误
    )
    goto :error_exit
)

echo   [OK] 构建成功: auth-service.exe

REM 显示文件信息
for %%F in (auth-service.exe) do (
    echo        文件大小: %%~zF bytes
)

echo.

REM ============================================================
REM 步骤 6: 验证构建结果
REM ============================================================

echo [步骤 6/6] 验证构建结果...
echo.

cd /d "%AUTH_SERVICE_DIR%"

REM 检查可执行文件
if exist "auth-service.exe" (
    echo   [OK] 可执行文件已生成: auth-service.exe
) else (
    echo [错误] 未找到构建输出
    goto :error_exit
)

REM 如果是CGO模式，检查DLL依赖
if "%BUILD_MODE%"=="cgo" (
    echo.
    echo   检查DLL依赖...
    
    REM 复制必要的DLL到输出目录
    if exist "%SQLITE_DLL_DIR%\sqlite3.dll" (
        copy "%SQLITE_DLL_DIR%\sqlite3.dll" "%AUTH_SERVICE_DIR%\" >nul 2>&1
        if exist "%AUTH_SERVICE_DIR%\sqlite3.dll" (
            echo   [OK] sqlite3.dll 已复制到输出目录
        )
    )
)

REM 测试运行（显示帮助信息）
echo.
echo   测试可执行文件...
auth-service.exe --help >nul 2>&1
if %ERRORLEVEL% leq 1 (
    echo   [OK] 可执行文件测试通过
) else (
    echo   [警告] 可执行文件可能需要额外的DLL依赖
    if "%BUILD_MODE%"=="cgo" (
        echo        请确保 sqlite3.dll 在PATH中或与可执行文件同目录
    )
)

echo.

REM ============================================================
REM 构建其他服务（如果指定 --all）
REM ============================================================

if "%BUILD_ALL%"=="1" (
    echo [额外] 构建其他服务...
    echo.
    
    call :build_other_services
    
    echo.
)

REM ============================================================
REM 构建完成
REM ============================================================

echo ============================================================
echo    构建完成！
echo ============================================================
echo.
echo   构建信息:
echo   ------------------------------------------------------------
echo   构建模式:     %BUILD_MODE%
if "%BUILD_MODE%"=="cgo" (
    echo   SQLite3库:    %SQLITE_DLL_DIR%
)
echo   可执行文件:   %AUTH_SERVICE_DIR%\auth-service.exe
echo   ------------------------------------------------------------
echo.
echo   运行服务:
echo   ------------------------------------------------------------
echo   cd services\auth-service
echo   set USE_SQLITE=true
echo   auth-service.exe
echo   ------------------------------------------------------------
echo.
if "%BUILD_MODE%"=="cgo" (
    echo   [注意] CGO模式构建的可执行文件需要 sqlite3.dll
    echo          请确保 sqlite3.dll 与可执行文件在同一目录
) else (
    echo   [提示] 纯Go模式构建的可执行文件无需外部依赖
    echo          可以直接分发和运行
)
echo.

goto :end

REM ============================================================
REM 子程序: 检查C编译器
REM ============================================================

:check_c_compiler
where gcc >nul 2>&1
if %ERRORLEVEL% equ 0 (
    for /f "tokens=*" %%v in ('gcc --version 2^>nul ^| findstr /r "gcc"') do set GCC_VERSION=%%v
    echo   [OK] C编译器: !GCC_VERSION!
    exit /b 0
)

where cl >nul 2>&1
if %ERRORLEVEL% equ 0 (
    echo   [OK] C编译器: MSVC cl.exe
    exit /b 0
)

echo [错误] CGO模式需要C编译器 - gcc 或 MSVC cl
echo        请安装 MinGW-w64 或 Visual Studio Build Tools
exit /b 1

REM ============================================================
REM 子程序: 设置CGO SQLite
REM ============================================================

:setup_cgo_sqlite
REM 检查是否已解压SQLite3库
if exist "%SQLITE_DLL_DIR%\sqlite3.dll" (
    echo   [OK] SQLite3 DLL 已存在: %SQLITE_DLL_DIR%\sqlite3.dll
    goto :sqlite_env_setup
)

REM 检查ZIP文件是否存在
if not exist "%SQLITE_DLL_ZIP%" (
    echo [错误] 未找到本地 SQLite3 库文件
    echo.
    echo        CGO模式需要本地SQLite3库。请执行以下操作之一:
    echo.
    echo        1. 下载预编译的SQLite3库:
    echo           访问 https://www.sqlite.org/download.html
    echo           下载 sqlite-dll-win64-x64-*.zip
    echo           将ZIP文件保存为: %SQLITE_DLL_ZIP%
    echo.
    echo        2. 或者使用纯Go模式构建 - 无需外部依赖:
    echo           build-services.bat --pure-go
    echo.
    exit /b 1
)

echo   [OK] 找到 SQLite3 ZIP 文件: %SQLITE_DLL_ZIP%
echo        正在解压...

REM 创建目标目录
if not exist "%SQLITE_DLL_DIR%" mkdir "%SQLITE_DLL_DIR%"

REM 使用PowerShell解压
powershell -Command "Expand-Archive -Path '%SQLITE_DLL_ZIP%' -DestinationPath '%SQLITE_DLL_DIR%' -Force"
if %ERRORLEVEL% neq 0 (
    echo [错误] 解压 SQLite3 ZIP 失败
    exit /b 1
)

REM 验证解压结果
if exist "%SQLITE_DLL_DIR%\sqlite3.dll" (
    echo   [OK] SQLite3 DLL 解压成功
    goto :sqlite_env_setup
)

REM 可能在子目录中，尝试查找
for /r "%SQLITE_DLL_DIR%" %%f in (sqlite3.dll) do (
    copy "%%f" "%SQLITE_DLL_DIR%\sqlite3.dll" >nul 2>&1
)

if not exist "%SQLITE_DLL_DIR%\sqlite3.dll" (
    echo [错误] 未找到 sqlite3.dll 文件
    echo        请确保 %SQLITE_DLL_ZIP% 包含有效的 sqlite3.dll
    exit /b 1
)

echo   [OK] SQLite3 DLL 已定位并复制

REM 查找并复制头文件
for /r "%SQLITE_DLL_DIR%" %%f in (sqlite3.h) do (
    copy "%%f" "%SQLITE_DLL_DIR%\sqlite3.h" >nul 2>&1
)

:sqlite_env_setup
REM 设置CGO环境变量
set "CGO_ENABLED=1"
set "CGO_CFLAGS=-I%SQLITE_DLL_DIR%"
set "CGO_LDFLAGS=-L%SQLITE_DLL_DIR%"

REM 将DLL目录添加到PATH
set "PATH=%SQLITE_DLL_DIR%;%PATH%"

echo   [OK] CGO 环境变量已配置
echo        CGO_ENABLED=1
echo        CGO_CFLAGS=-I%SQLITE_DLL_DIR%
echo        CGO_LDFLAGS=-L%SQLITE_DLL_DIR%

exit /b 0

REM ============================================================
REM 子程序: 构建其他服务
REM ============================================================

:build_other_services
REM 构建 admin-service
echo   构建 admin-service...
cd /d "%SCRIPT_DIR%services\admin-service"
if exist "cmd\main.go" (
    go build -ldflags "-s -w" -o admin-service.exe ./cmd/main.go
    if !ERRORLEVEL! equ 0 (
        echo   [OK] admin-service.exe
    ) else (
        echo   [警告] admin-service 构建失败
    )
) else (
    echo   [跳过] admin-service 无 main.go
)

REM 构建 cleanup-service
echo   构建 cleanup-service...
cd /d "%SCRIPT_DIR%services\cleanup-service"
if exist "cmd\main.go" (
    go build -ldflags "-s -w" -o cleanup-service.exe ./cmd/main.go
    if !ERRORLEVEL! equ 0 (
        echo   [OK] cleanup-service.exe
    ) else (
        echo   [警告] cleanup-service 构建失败
    )
) else (
    echo   [跳过] cleanup-service 无 main.go
)

REM 构建 media-proxy
echo   构建 media-proxy...
cd /d "%SCRIPT_DIR%services\media-proxy"
if exist "cmd\main.go" (
    go build -ldflags "-s -w" -o media-proxy.exe ./cmd/main.go
    if !ERRORLEVEL! equ 0 (
        echo   [OK] media-proxy.exe
    ) else (
        echo   [警告] media-proxy 构建失败
    )
) else (
    echo   [跳过] media-proxy 无 main.go
)

REM 构建 permission-service
echo   构建 permission-service...
cd /d "%SCRIPT_DIR%services\permission-service"
if exist "cmd\main.go" (
    go build -ldflags "-s -w" -o permission-service.exe ./cmd/main.go
    if !ERRORLEVEL! equ 0 (
        echo   [OK] permission-service.exe
    ) else (
        echo   [警告] permission-service 构建失败
    )
) else (
    echo   [跳过] permission-service 无 main.go
)

REM 构建 push-service
echo   构建 push-service...
cd /d "%SCRIPT_DIR%services\push-service"
if exist "cmd\main.go" (
    go build -ldflags "-s -w" -o push-service.exe ./cmd/main.go
    if !ERRORLEVEL! equ 0 (
        echo   [OK] push-service.exe
    ) else (
        echo   [警告] push-service 构建失败
    )
) else (
    echo   [跳过] push-service 无 main.go
)

exit /b 0

REM ============================================================
REM 帮助信息
REM ============================================================

:show_help
echo.
echo 使用方法: build-services.bat [选项]
echo.
echo 选项:
echo   --pure-go    使用纯Go模式构建（默认）
echo                使用 glebarez/sqlite 驱动，无需外部SQLite3库
echo                构建出的可执行文件可以直接分发
echo.
echo   --cgo        使用CGO模式构建
echo                需要本地SQLite3库文件（sqlite3.dll, sqlite3.h）
echo                需要C编译器（gcc 或 MSVC）
echo                适用于需要CGO依赖的场景
echo.
echo   --clean      清理构建缓存后再构建
echo.
echo   --all        构建所有服务（包括其他微服务）
echo.
echo   --help, -h   显示此帮助信息
echo.
echo 示例:
echo   build-services.bat                    # 使用纯Go模式构建
echo   build-services.bat --cgo              # 使用CGO模式构建
echo   build-services.bat --clean --pure-go  # 清理后使用纯Go模式构建
echo.
echo 本地SQLite3库配置:
echo   如果使用CGO模式，请将SQLite3库文件放置在以下位置之一:
echo   1. %SQLITE_DLL_ZIP% - ZIP文件，会自动解压
echo   2. %SQLITE_DLL_DIR%\sqlite3.dll - 已解压的DLL文件
echo.
echo   下载地址: https://www.sqlite.org/download.html
echo   选择 "Precompiled Binaries for Windows" 下的
echo   sqlite-dll-win64-x64-*.zip - 64位
echo   sqlite-dll-win32-x86-*.zip - 32位
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
