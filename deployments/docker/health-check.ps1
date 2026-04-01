# ============================================================
# 服务器健康检查脚本 (在服务器本地运行)
# 使用方式: 在服务器上以管理员权限运行
# ============================================================

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "服务器健康检查" -ForegroundColor Cyan
Write-Host "运行时间: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# 1. 系统信息
Write-Host "=== 系统信息 ===" -ForegroundColor Yellow
Write-Host "计算机名: $env:COMPUTERNAME"
Write-Host "操作系统: $(Get-CimInstance Win32_OperatingSystem | Select-Object -ExpandProperty Caption)"
Write-Host "系统架构: $env:PROCESSOR_ARCHITECTURE"
Write-Host "可用内存: $([math]::Round((Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory/1MB, 2)) GB"
Write-Host ""

# 2. 网络配置
Write-Host "=== 网络配置 ===" -ForegroundColor Yellow
$ipAddresses = Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -notlike "*Loopback*" }
foreach ($ip in $ipAddresses) {
    Write-Host "$($ip.InterfaceAlias): $($ip.IPAddress)"
}
Write-Host ""

# 3. 防火墙状态
Write-Host "=== 防火墙状态 ===" -ForegroundColor Yellow
$firewallProfiles = Get-NetFirewallProfile
foreach ($profile in $firewallProfiles) {
    Write-Host "$($profile.Name): $($profile.Enabled)"
}
Write-Host ""

Write-Host "已开放的端口规则:" -ForegroundColor Gray
Get-NetFirewallRule | Where-Object { $_.Enabled -eq 'True' -and $_.Direction -eq 'Inbound' -and $_.Action -eq 'Allow' } |
    Where-Object { $_.Name -match '^(SSH|HTTP|HTTPS|API)$' } |
    ForEach-Object {
        $ports = Get-NetFirewallPortFilter -AssociatedNetFirewallRule $_
        Write-Host "  $($_.DisplayName): 端口 $($ports.LocalPort)" -ForegroundColor Gray
    }
Write-Host ""

# 4. Docker状态
Write-Host "=== Docker状态 ===" -ForegroundColor Yellow

$dockerService = Get-Service -Name "com.docker.service" -ErrorAction SilentlyContinue
if ($dockerService) {
    Write-Host "Docker Desktop服务: $($dockerService.Status)"
} else {
    Write-Host "Docker Desktop服务: 未安装或未运行" -ForegroundColor Red
}

Write-Host ""
Write-Host "Docker容器状态:" -ForegroundColor Gray
try {
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  Docker未就绪或无运行容器" -ForegroundColor Red
    }
} catch {
    Write-Host "  Docker命令执行失败" -ForegroundColor Red
}
Write-Host ""

# 5. 端口监听状态
Write-Host "=== 端口监听状态 ===" -ForegroundColor Yellow

$ports = @(80, 443, 8081, 5432, 6379)
foreach ($port in $ports) {
    $listener = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue
    if ($listener) {
        $process = Get-Process -Id $listener.OwningProcess -ErrorAction SilentlyContinue
        Write-Host "端口 $port : 监听中 (进程: $($process.ProcessName))" -ForegroundColor Green
    } else {
        Write-Host "端口 $port : 未监听" -ForegroundColor Red
    }
}
Write-Host ""

# 6. 本地健康检查
Write-Host "=== 本地健康检查 ===" -ForegroundColor Yellow

$endpoints = @(
    @{Url = "http://localhost/health"; Name = "Nginx -> API"},
    @{Url = "http://localhost:8081/health"; Name = "API直接访问"},
    @{Url = "http://localhost/nginx-health"; Name = "Nginx健康检查"}
)

foreach ($endpoint in $endpoints) {
    Write-Host "$($endpoint.Name)... " -NoNewline
    try {
        $response = Invoke-WebRequest -Uri $endpoint.Url -TimeoutSec 5 -UseBasicParsing -ErrorAction Stop
        if ($response.StatusCode -eq 200) {
            Write-Host "[通过] 状态码: $($response.StatusCode)" -ForegroundColor Green
        } else {
            Write-Host "[警告] 状态码: $($response.StatusCode)" -ForegroundColor Yellow
        }
    } catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        if ($statusCode) {
            Write-Host "[响应] 状态码: $statusCode" -ForegroundColor Yellow
        } else {
            Write-Host "[失败] 无响应" -ForegroundColor Red
        }
    }
}
Write-Host ""

# 7. Docker容器健康检查
Write-Host "=== Docker容器健康检查 ===" -ForegroundColor Yellow

try {
    $containers = docker ps --format "{{.Names}}" 2>$null
    foreach ($container in $containers) {
        Write-Host "容器 $container 健康检查:" -ForegroundColor Gray
        $health = docker inspect --format='{{.State.Health.Status}}' $container 2>$null
        if ($health -eq "healthy") {
            Write-Host "  状态: 健康" -ForegroundColor Green
        } elseif ($health -eq "unhealthy") {
            Write-Host "  状态: 不健康" -ForegroundColor Red
            Write-Host "  日志:" -ForegroundColor Gray
            docker inspect --format='{{range .State.Health.Log}}{{.Output}}{{end}}' $container 2>$null
        } else {
            Write-Host "  状态: $health" -ForegroundColor Yellow
        }
    }
} catch {
    Write-Host "无法获取容器健康状态" -ForegroundColor Red
}
Write-Host ""

# 8. 磁盘空间
Write-Host "=== 磁盘空间 ===" -ForegroundColor Yellow
Get-CimInstance Win32_LogicalDisk | Where-Object { $_.DriveType -eq 3 } | ForEach-Object {
    $free = [math]::Round($_.FreeSpace / 1GB, 2)
    $total = [math]::Round($_.Size / 1GB, 2)
    $used = [math]::Round(($total - $free), 2)
    Write-Host "$($_.DeviceID) 已用: ${used}GB / ${total}GB (剩余: ${free}GB)"
}
Write-Host ""

# 9. 最近错误日志
Write-Host "=== 最近的系统错误 ===" -ForegroundColor Yellow
Get-EventLog -LogName System -EntryType Error -Newest 5 -ErrorAction SilentlyContinue |
    Select-Object TimeGenerated, Source, Message |
    Format-Table -AutoSize -Wrap
Write-Host ""

# 10. 总结
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "健康检查完成" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "外网访问地址:" -ForegroundColor White
Write-Host "  HTTP:  http://8.130.55.126" -ForegroundColor Cyan
Write-Host "  API:   http://8.130.55.126:8081" -ForegroundColor Cyan
Write-Host "  健康检查: http://8.130.55.126/health" -ForegroundColor Cyan
Write-Host ""
Write-Host "管理命令:" -ForegroundColor White
Write-Host "  查看容器: docker ps" -ForegroundColor Gray
Write-Host "  查看日志: docker compose logs -f" -ForegroundColor Gray
Write-Host "  重启服务: docker compose restart" -ForegroundColor Gray
Write-Host "  停止服务: docker compose down" -ForegroundColor Gray
