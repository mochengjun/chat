# Docker ZeroTier网络配置
# 配置Docker通过ZeroTier网络访问外部资源

Write-Host "=== Docker ZeroTier网络配置 ===" -ForegroundColor Green

# 获取ZeroTier网络接口信息
Write-Host "`n1. 检查ZeroTier网络接口：" -ForegroundColor Yellow
$ztInterfaces = Get-NetAdapter | Where-Object {$_.Name -like "*ZeroTier*"}
if ($ztInterfaces) {
    Write-Host "找到ZeroTier接口：" -ForegroundColor Green
    $ztInterfaces | Format-Table Name, InterfaceIndex, Status
} else {
    Write-Host "未找到ZeroTier网络接口" -ForegroundColor Yellow
    Write-Host "请先运行 connect_to_zerotier.bat 并在ZeroTier Central授权节点" -ForegroundColor Cyan
    exit 1
}

# 获取ZeroTier分配的IP地址
Write-Host "`n2. 获取ZeroTier IP地址：" -ForegroundColor Yellow
$ztIP = & "C:\Program Files (x86)\ZeroTier\One\zerotier-cli.bat" listnetworks | Select-String "6AB565387A193124" | ForEach-Object {
    if ($_ -match '(\d+\.\d+\.\d+\.\d+)/\d+') {
        $matches[1]
    }
}

if ($ztIP) {
    Write-Host "ZeroTier IP: $ztIP" -ForegroundColor Green
} else {
    Write-Host "无法获取ZeroTier IP地址" -ForegroundColor Red
    exit 1
}

# 配置Docker使用ZeroTier网络
Write-Host "`n3. 配置Docker网络设置：" -ForegroundColor Yellow

# 更新daemon.json配置
$daemonConfigPath = "$env:ProgramData\docker\config\daemon.json"
$dockerConfig = @{
    "proxies" = @{
        "default" = @{
            "httpProxy" = "http://${ztIP}:9993"
            "httpsProxy" = "http://${ztIP}:9993"
            "noProxy" = "localhost,127.0.0.1,hubproxy.docker.internal"
        }
    }
    "registry-mirrors" = @(
        "https://docker.mirrors.ustc.edu.cn",
        "https://hub-mirror.c.163.com"
    )
}

# 保存配置
if (!(Test-Path (Split-Path $daemonConfigPath))) {
    New-Item -ItemType Directory -Path (Split-Path $daemonConfigPath) -Force
}

$dockerConfig | ConvertTo-Json -Depth 4 | Out-File -FilePath $daemonConfigPath -Encoding UTF8
Write-Host "已更新Docker配置文件: $daemonConfigPath" -ForegroundColor Green

# 重启Docker服务
Write-Host "`n4. 重启Docker服务：" -ForegroundColor Yellow
try {
    Stop-Process -Name "Docker Desktop" -Force -ErrorAction Stop
    Write-Host "已停止Docker Desktop" -ForegroundColor Green
} catch {
    Write-Host "停止Docker Desktop失败: $($_.Exception.Message)" -ForegroundColor Yellow
}

Start-Sleep -Seconds 5

try {
    Start-Process "C:\Program Files\Docker\Docker\Docker Desktop.exe"
    Write-Host "已启动Docker Desktop" -ForegroundColor Green
} catch {
    Write-Host "启动Docker Desktop失败: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n=== 配置完成 ===" -ForegroundColor Green
Write-Host "请执行以下验证步骤：" -ForegroundColor Cyan
Write-Host "1. 等待Docker完全启动（约2分钟）" -ForegroundColor White
Write-Host "2. 运行: docker info | Select-String -Pattern 'Proxy'" -ForegroundColor White
Write-Host "3. 测试镜像拉取: docker pull alpine:latest" -ForegroundColor White