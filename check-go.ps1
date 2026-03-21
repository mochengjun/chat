# Go 环境检查和配置脚本
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "   Go 环境检查" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

# 检查 Go 命令
$goCmd = Get-Command go -ErrorAction SilentlyContinue

if ($goCmd) {
    Write-Host "[OK] Go 已安装" -ForegroundColor Green
    go version
    
    Write-Host ""
    Write-Host "配置 Go 代理..." -ForegroundColor Yellow
    go env -w GOPROXY=https://goproxy.cn,https://goproxy.io,direct
    go env -w GOSUMDB=sum.golang.google.cn
    
    Write-Host "[OK] Go 代理已配置" -ForegroundColor Green
    go env GOPROXY
} else {
    Write-Host "[警告] Go 未安装" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "请下载并安装 Go 1.23+:" -ForegroundColor Yellow
    Write-Host "https://golang.org/dl/"
}
