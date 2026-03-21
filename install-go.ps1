# Go 环境安装脚本
# 使用方法: PowerShell -ExecutionPolicy Bypass -File install-go.ps1

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "   Go 环境安装脚本" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

# 检查是否已安装Go
Write-Host "[步骤 1/5] 检查 Go 环境..." -ForegroundColor Yellow
$goInstalled = Get-Command go -ErrorAction SilentlyContinue

if ($goInstalled) {
    $goVersion = go version
    Write-Host "  [OK] Go 已安装: $goVersion" -ForegroundColor Green
    
    # 检查版本是否符合要求
    if ($goVersion -match "go(\d+)\.(\d+)") {
        $major = [int]$matches[1]
        $minor = [int]$matches[2]
        if ($major -gt 1 -or ($major -eq 1 -and $minor -ge 23)) {
            Write-Host "  [OK] Go 版本符合要求 (>= 1.23)" -ForegroundColor Green
        } else {
            Write-Host "  [警告] Go 版本过低,建议升级到 1.23+" -ForegroundColor Yellow
        }
    }
    
    # 配置 Go 代理
    Write-Host ""
    Write-Host "[步骤 2/5] 配置 Go 代理..." -ForegroundColor Yellow
    go env -w GOPROXY=https://goproxy.cn,https://goproxy.io,direct
    go env -w GOSUMDB=sum.golang.google.cn
    go env -w GO111MODULE=on
    
    $goproxy = go env GOPROXY
    Write-Host "  [OK] GOPROXY: $goproxy" -ForegroundColor Green
    
    # 测试 Go 编译
    Write-Host ""
    Write-Host "[步骤 3/5] 测试 Go 编译..." -ForegroundColor Yellow
    
    $testCode = @"
package main
import "fmt"
func main() {
    fmt.Println("Hello, Go!")
}
"@
    
    $testFile = "test_go.go"
    $testCode | Out-File -FilePath $testFile -Encoding utf8
    
    go build -o test_go.exe $testFile
    
    if (Test-Path "test_go.exe") {
        Write-Host "  [OK] Go 编译测试成功" -ForegroundColor Green
        Remove-Item "test_go.exe" -Force
        Remove-Item $testFile -Force
    } else {
        Write-Host "  [警告] Go 编译测试失败" -ForegroundColor Yellow
    }
    
    # 验证 GOPATH
    Write-Host ""
    Write-Host "[步骤 4/5] 验证 GOPATH..." -ForegroundColor Yellow
    $gopath = go env GOPATH
    Write-Host "  [OK] GOPATH: $gopath" -ForegroundColor Green
    
    if (-not (Test-Path $gopath)) {
        New-Item -ItemType Directory -Path $gopath -Force | Out-Null
        Write-Host "  [OK] 已创建 GOPATH 目录" -ForegroundColor Green
    }
    
    # 完成
    Write-Host ""
    Write-Host "[步骤 5/5] 安装完成!" -ForegroundColor Green
    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "   Go 环境配置完成" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Go 版本: " -NoNewline
    go version
    Write-Host "GOPROXY: " -NoNewline
    go env GOPROXY
    Write-Host "GOPATH: " -NoNewline
    go env GOPATH
    Write-Host ""
    
    exit 0
}

# Go 未安装,提供安装指导
Write-Host "  [信息] Go 未安装" -ForegroundColor Yellow
Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "   Go 安装指南" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "请按以下步骤安装 Go 1.23+:" -ForegroundColor Yellow
Write-Host ""
Write-Host "方法 1: 手动安装 (推荐)"
Write-Host "  1. 访问: https://golang.org/dl/"
Write-Host "  2. 下载: go1.23.x.windows-amd64.msi"
Write-Host "  3. 双击安装程序,按向导完成安装"
Write-Host "  4. 重启 PowerShell 终端"
Write-Host "  5. 再次运行此脚本验证安装"
Write-Host ""
Write-Host "方法 2: 使用 Chocolatey (如果已安装)"
Write-Host "  choco install golang -y"
Write-Host ""
Write-Host "方法 3: 使用 Scoop (如果已安装)"
Write-Host "  scoop install go"
Write-Host ""
Write-Host "安装完成后,运行以下命令配置代理:"
Write-Host "  go env -w GOPROXY=https://goproxy.cn,direct"
Write-Host "  go env -w GOSUMDB=sum.golang.google.cn"
Write-Host ""

exit 1
