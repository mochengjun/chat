@echo off
chcp 65001 >nul
echo ============================================================
echo    Go 环境检查
echo ============================================================
echo.

where go >nul 2>&1
if %ERRORLEVEL% equ 0 (
    echo [OK] Go 已安装
    go version
    echo.
    echo 配置 Go 代理...
    go env -w GOPROXY=https://goproxy.cn,https://goproxy.io,direct
    go env -w GOSUMDB=sum.golang.google.cn
    echo [OK] Go 代理已配置
    echo.
    echo GOPROXY:
    go env GOPROXY
) else (
    echo [警告] Go 未安装
    echo.
    echo 请下载并安装 Go 1.23+:
    echo https://golang.org/dl/
    echo.
    echo 安装步骤:
    echo 1. 访问 https://golang.org/dl/
    echo 2. 下载 go1.23.x.windows-amd64.msi
    echo 3. 双击安装程序
    echo 4. 重启终端
)

echo.
pause
