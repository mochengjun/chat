# Docker代理配置脚本
# 请根据实际情况修改代理服务器地址

Write-Host "=== Docker代理配置工具 ===" -ForegroundColor Green

# 配置参数（请根据实际情况修改）
$proxyServer = "your-proxy-server"  # 替换为实际代理服务器
$proxyPort = "8080"                 # 替换为实际端口
$httpProxy = "http://${proxyServer}:${proxyPort}"
$httpsProxy = "http://${proxyServer}:${proxyPort}"

# 显示当前配置
Write-Host "`n当前Docker配置：" -ForegroundColor Yellow
docker info | Select-String -Pattern "Proxy"

# 方法1: 通过环境变量配置（临时）
Write-Host "`n方法1: 设置环境变量（临时生效）" -ForegroundColor Cyan
$env:HTTP_PROXY = $httpProxy
$env:HTTPS_PROXY = $httpsProxy
$env:NO_PROXY = "localhost,127.0.0.1,hubproxy.docker.internal"

Write-Host "已设置环境变量："
Write-Host "HTTP_PROXY = $httpProxy"
Write-Host "HTTPS_PROXY = $httpsProxy"
Write-Host "NO_PROXY = localhost,127.0.0.1,hubproxy.docker.internal"

# 方法2: 配置Docker daemon（永久）
Write-Host "`n方法2: 配置Docker daemon.json（永久生效）" -ForegroundColor Cyan
$daemonConfigPath = "$env:ProgramData\docker\config\daemon.json"

# 创建配置目录（如果不存在）
if (!(Test-Path (Split-Path $daemonConfigPath))) {
    New-Item -ItemType Directory -Path (Split-Path $daemonConfigPath) -Force
}

# 创建或更新daemon.json
$daemonConfig = @{
    "proxies" = @{
        "default" = @{
            "httpProxy" = $httpProxy
            "httpsProxy" = $httpsProxy
            "noProxy" = "localhost,127.0.0.1,hubproxy.docker.internal"
        }
    }
}

$daemonConfig | ConvertTo-Json -Depth 3 | Out-File -FilePath $daemonConfigPath -Encoding UTF8
Write-Host "已创建/更新配置文件: $daemonConfigPath"

# 重启Docker服务
Write-Host "`n正在重启Docker服务..." -ForegroundColor Yellow
Restart-Service com.docker.service
Start-Sleep -Seconds 10

Write-Host "`n=== 配置完成 ===" -ForegroundColor Green
Write-Host "请重新打开终端窗口以使环境变量生效"
Write-Host "验证命令: docker info | findstr -i proxy"