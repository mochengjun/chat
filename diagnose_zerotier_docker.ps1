# ZeroTier网络诊断和Docker配置修复脚本

Write-Host "=== ZeroTier网络诊断 ===" -ForegroundColor Green

# 1. 检查ZeroTier服务状态
Write-Host "`n1. 检查ZeroTier服务：" -ForegroundColor Yellow
try {
    $ztService = Get-Service "ZeroTier One" -ErrorAction Stop
    Write-Host "服务状态: $($ztService.Status)" -ForegroundColor Green
} catch {
    Write-Host "ZeroTier服务未找到或无法访问" -ForegroundColor Red
}

# 2. 检查ZeroTier节点信息
Write-Host "`n2. 检查ZeroTier节点信息：" -ForegroundColor Yellow
try {
    $ztInfo = & "C:\Program Files (x86)\ZeroTier\One\zerotier-cli.bat" info 2>$null
    if ($ztInfo) {
        Write-Host "节点信息: $ztInfo" -ForegroundColor Green
    } else {
        Write-Host "无法获取节点信息" -ForegroundColor Red
    }
} catch {
    Write-Host "ZeroTier CLI访问失败" -ForegroundColor Red
}

# 3. 检查网络连接
Write-Host "`n3. 检查网络连接：" -ForegroundColor Yellow
try {
    $ztNetworks = & "C:\Program Files (x86)\ZeroTier\One\zerotier-cli.bat" listnetworks 2>$null
    if ($ztNetworks) {
        Write-Host "网络列表：" -ForegroundColor Cyan
        $ztNetworks | ForEach-Object { Write-Host "  $_" }
    } else {
        Write-Host "未连接到任何网络" -ForegroundColor Yellow
    }
} catch {
    Write-Host "无法获取网络列表" -ForegroundColor Red
}

# 4. 检查网络接口
Write-Host "`n4. 检查网络接口：" -ForegroundColor Yellow
$ztAdapters = Get-NetAdapter | Where-Object {$_.Name -like "*ZeroTier*"}
if ($ztAdapters) {
    $ztAdapters | Format-Table Name, InterfaceIndex, Status, LinkSpeed
} else {
    Write-Host "未找到ZeroTier网络接口" -ForegroundColor Red
}

# 5. 检查路由表
Write-Host "`n5. 检查相关路由：" -ForegroundColor Yellow
$routeTable = route print | Select-String "172.25|ZeroTier"
if ($routeTable) {
    $routeTable | ForEach-Object { Write-Host "  $_" }
} else {
    Write-Host "未找到相关路由" -ForegroundColor Yellow
}

# 6. 测试网络连通性
Write-Host "`n6. 测试网络连通性：" -ForegroundColor Yellow
$testIP = "172.25.118.254"  # 从截图中获取的IP
try {
    $pingResult = Test-Connection -ComputerName $testIP -Count 2 -Quiet
    if ($pingResult) {
        Write-Host "✓ 能够ping通ZeroTier IP: $testIP" -ForegroundColor Green
    } else {
        Write-Host "✗ 无法ping通ZeroTier IP: $testIP" -ForegroundColor Red
    }
} catch {
    Write-Host "✗ ping测试失败: $($_.Exception.Message)" -ForegroundColor Red
}

# 7. 配置Docker使用ZeroTier网络
Write-Host "`n7. 配置Docker网络：" -ForegroundColor Yellow

$dockerConfig = @{
    "proxies" = @{
        "default" = @{
            "httpProxy" = "http://172.25.118.254:9993"
            "httpsProxy" = "http://172.25.118.254:9993"
            "noProxy" = "localhost,127.0.0.1,hubproxy.docker.internal"
        }
    }
    "registry-mirrors" = @(
        "https://docker.mirrors.ustc.edu.cn",
        "https://hub-mirror.c.163.com"
    )
}

$configPath = "$env:ProgramData\docker\config\daemon.json"
try {
    if (!(Test-Path (Split-Path $configPath))) {
        New-Item -ItemType Directory -Path (Split-Path $configPath) -Force
    }
    
    $dockerConfig | ConvertTo-Json -Depth 4 | Out-File -FilePath $configPath -Encoding UTF8
    Write-Host "✓ 已更新Docker配置文件" -ForegroundColor Green
    Write-Host "配置文件位置: $configPath" -ForegroundColor Cyan
} catch {
    Write-Host "✗ 更新Docker配置失败: $($_.Exception.Message)" -ForegroundColor Red
}

# 8. 显示当前配置
Write-Host "`n8. 当前Docker配置：" -ForegroundColor Yellow
if (Test-Path $configPath) {
    Get-Content $configPath | ConvertFrom-Json | Format-List
}

Write-Host "`n=== 诊断完成 ===" -ForegroundColor Green
Write-Host "建议的下一步：" -ForegroundColor Cyan
Write-Host "1. 如果ZeroTier连接正常，重启Docker服务" -ForegroundColor White
Write-Host "2. 测试镜像拉取: docker pull alpine:latest" -ForegroundColor White
Write-Host "3. 如仍有问题，检查防火墙设置" -ForegroundColor White