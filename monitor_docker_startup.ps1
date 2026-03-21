# Docker启动监控脚本
# 等待Docker完全启动并验证网络配置

Write-Host "=== Docker启动监控 ===" -ForegroundColor Green

$maxAttempts = 30
$attempt = 0

while ($attempt -lt $maxAttempts) {
    $attempt++
    Write-Host "`n尝试 $attempt/$maxAttempts ..." -ForegroundColor Yellow
    
    try {
        # 测试Docker连接
        $version = docker version --format "{{.Server.Version}}" 2>$null
        if ($version) {
            Write-Host "✓ Docker服务已启动，版本: $version" -ForegroundColor Green
            
            # 检查代理配置
            Write-Host "`n检查代理配置..." -ForegroundColor Cyan
            $proxyInfo = docker info 2>$null | Select-String "Proxy"
            if ($proxyInfo) {
                Write-Host "代理配置：" -ForegroundColor Green
                $proxyInfo | ForEach-Object { Write-Host "  $_" }
            } else {
                Write-Host "未检测到代理配置" -ForegroundColor Yellow
            }
            
            # 测试镜像拉取
            Write-Host "`n测试镜像拉取..." -ForegroundColor Cyan
            $pullResult = docker pull alpine:latest 2>&1
            if ($pullResult -match "Status: Downloaded") {
                Write-Host "✓ 镜像拉取成功！" -ForegroundColor Green
                break
            } elseif ($pullResult -match "failed") {
                Write-Host "✗ 镜像拉取失败: $pullResult" -ForegroundColor Red
            } else {
                Write-Host "镜像拉取中..." -ForegroundColor Yellow
            }
            
        } else {
            Write-Host "Docker服务仍在启动中..." -ForegroundColor Yellow
        }
    } catch {
        Write-Host "Docker服务未响应: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    if ($attempt -lt $maxAttempts) {
        Start-Sleep -Seconds 10
    }
}

if ($attempt -ge $maxAttempts) {
    Write-Host "`n⚠ 超时：Docker启动时间超过预期" -ForegroundColor Yellow
    Write-Host "建议检查：" -ForegroundColor Cyan
    Write-Host "1. Docker Desktop GUI状态" -ForegroundColor White
    Write-Host "2. Windows通知区域的Docker图标" -ForegroundColor White
    Write-Host "3. 任务管理器中的Docker进程" -ForegroundColor White
} else {
    Write-Host "`n=== 监控完成 ===" -ForegroundColor Green
}

Write-Host "`n当前Docker配置：" -ForegroundColor Yellow
docker info | Select-String -Pattern "Proxy|Registry Mirrors" -Context 0,2