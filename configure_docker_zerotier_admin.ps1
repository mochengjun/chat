# Docker ZeroTier网络配置（管理员权限版本）
# 配置Docker通过ZeroTier网络访问外部资源

param(
    [Parameter(Mandatory=$false)]
    [string]$ZTNetworkIP = "10.147.20.100"  # 默认ZeroTier IP，可根据实际情况修改
)

Write-Host "=== Docker ZeroTier网络配置（管理员权限）===" -ForegroundColor Green

# 检查管理员权限
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "⚠ 需要管理员权限来获取ZeroTier网络信息" -ForegroundColor Yellow
    Write-Host "请以管理员身份运行此脚本" -ForegroundColor Cyan
    exit 1
}

# 获取ZeroTier网络接口信息
Write-Host "`n1. 检查ZeroTier网络接口：" -ForegroundColor Yellow
$ztInterfaces = Get-NetAdapter | Where-Object {$_.Name -like "*ZeroTier*"}
if ($ztInterfaces) {
    Write-Host "找到ZeroTier接口：" -ForegroundColor Green
    $ztInterfaces | Format-Table Name, InterfaceIndex, Status
} else {
    Write-Host "未找到ZeroTier网络接口" -ForegroundColor Red
    exit 1
}

# 尝试获取ZeroTier分配的IP地址
Write-Host "`n2. 获取ZeroTier IP地址：" -ForegroundColor Yellow
try {
    $ztOutput = & "C:\Program Files (x86)\ZeroTier\One\zerotier-cli.bat" listnetworks 2>$null
    $ztIP = $ztOutput | Select-String "6AB565387A193124" | ForEach-Object {
        if ($_ -match '(\d+\.\d+\.\d+\.\d+)/\d+') {
            $matches[1]
        }
    }
    
    if ($ztIP) {
        Write-Host "ZeroTier IP: $ztIP" -ForegroundColor Green
    } else {
        Write-Host "无法自动获取ZeroTier IP，使用默认IP: $ZTNetworkIP" -ForegroundColor Yellow
        $ztIP = $ZTNetworkIP
    }
} catch {
    Write-Host "无法获取ZeroTier IP，使用默认IP: $ZTNetworkIP" -ForegroundColor Yellow
    $ztIP = $ZTNetworkIP
}

# 配置Docker使用ZeroTier网络
Write-Host "`n3. 配置Docker网络设置：" -ForegroundColor Yellow

# 更新daemon.json配置
$daemonConfigPath = "$env:ProgramData\docker\config\daemon.json"

# 读取现有配置或创建新配置
if (Test-Path $daemonConfigPath) {
    try {
        $existingConfig = Get-Content $daemonConfigPath | ConvertFrom-Json
        Write-Host "读取现有配置..." -ForegroundColor Cyan
    } catch {
        Write-Host "现有配置文件损坏，创建新配置" -ForegroundColor Yellow
        $existingConfig = @{}
    }
} else {
    $existingConfig = @{}
}

# 更新配置
$dockerConfig = $existingConfig.Clone()
$dockerConfig | Add-Member -MemberType NoteProperty -Name "proxies" -Value @{
    "default" = @{
        "httpProxy" = "http://${ztIP}:9993"
        "httpsProxy" = "http://${ztIP}:9993"
        "noProxy" = "localhost,127.0.0.1,hubproxy.docker.internal"
    }
} -Force

$dockerConfig | Add-Member -MemberType NoteProperty -Name "registry-mirrors" -Value @(
    "https://docker.mirrors.ustc.edu.cn",
    "https://hub-mirror.c.163.com"
) -Force

# 保存配置
$configDir = Split-Path $daemonConfigPath
if (!(Test-Path $configDir)) {
    New-Item -ItemType Directory -Path $configDir -Force
}

$dockerConfig | ConvertTo-Json -Depth 4 | Out-File -FilePath $daemonConfigPath -Encoding UTF8
Write-Host "已更新Docker配置文件: $daemonConfigPath" -ForegroundColor Green

# 显示配置内容
Write-Host "`n配置详情：" -ForegroundColor Yellow
Get-Content $daemonConfigPath

# 重启Docker服务
Write-Host "`n4. 重启Docker服务：" -ForegroundColor Yellow
try {
    Write-Host "停止Docker Desktop..." -ForegroundColor Cyan
    Stop-Process -Name "Docker Desktop" -Force -ErrorAction Stop
    Write-Host "✓ 已停止Docker Desktop" -ForegroundColor Green
} catch {
    Write-Host "⚠ 停止Docker Desktop失败: $($_.Exception.Message)" -ForegroundColor Yellow
}

Start-Sleep -Seconds 5

try {
    Write-Host "启动Docker Desktop..." -ForegroundColor Cyan
    Start-Process "C:\Program Files\Docker\Docker\Docker Desktop.exe"
    Write-Host "✓ 已启动Docker Desktop" -ForegroundColor Green
} catch {
    Write-Host "✗ 启动Docker Desktop失败: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n=== 配置完成 ===" -ForegroundColor Green
Write-Host "请执行以下验证步骤：" -ForegroundColor Cyan
Write-Host "1. 等待Docker完全启动（约2分钟）" -ForegroundColor White
Write-Host "2. 运行: docker info | Select-String -Pattern 'Proxy'" -ForegroundColor White
Write-Host "3. 测试镜像拉取: docker pull alpine:latest" -ForegroundColor White