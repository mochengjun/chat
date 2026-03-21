# Docker国内镜像加速器配置
# 适用于中国大陆用户

Write-Host "=== Docker国内镜像加速器配置 ===" -ForegroundColor Green

# 常用国内镜像加速器
$mirrors = @(
    "https://docker.mirrors.ustc.edu.cn",
    "https://hub-mirror.c.163.com",
    "https://mirror.baidubce.com",
    "https://ccr.ccs.tencentyun.com"
)

Write-Host "`n可用的镜像加速器：" -ForegroundColor Yellow
for ($i = 0; $i -lt $mirrors.Count; $i++) {
    Write-Host "$($i + 1). $($mirrors[$i])"
}

# 配置daemon.json
$daemonConfigPath = "$env:ProgramData\docker\config\daemon.json"

# 创建配置
$daemonConfig = @{
    "registry-mirrors" = $mirrors
    "insecure-registries" = @()
    "debug" = $false
    "experimental" = $false
}

# 保存配置
if (!(Test-Path (Split-Path $daemonConfigPath))) {
    New-Item -ItemType Directory -Path (Split-Path $daemonConfigPath) -Force
}

$daemonConfig | ConvertTo-Json -Depth 3 | Out-File -FilePath $daemonConfigPath -Encoding UTF8
Write-Host "`n已配置镜像加速器到: $daemonConfigPath"

# 重启Docker
Write-Host "`n正在重启Docker服务..." -ForegroundColor Yellow
Restart-Service com.docker.service
Start-Sleep -Seconds 15

Write-Host "`n=== 配置完成 ===" -ForegroundColor Green
Write-Host "验证方法："
Write-Host "1. 重新打开PowerShell终端"
Write-Host "2. 运行: docker info"
Write-Host "3. 查看 Registry Mirrors 部分"