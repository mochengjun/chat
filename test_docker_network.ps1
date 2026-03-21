# Docker网络诊断和直连测试脚本

Write-Host "=== Docker网络连接诊断 ===" -ForegroundColor Green

# 测试基本网络连接
Write-Host "`n1. 测试DNS解析：" -ForegroundColor Yellow
try {
    $dnsResult = Resolve-DnsName registry-1.docker.io -ErrorAction Stop
    Write-Host "✓ DNS解析成功" -ForegroundColor Green
    $dnsResult | Format-Table Name, IPAddress -AutoSize
} catch {
    Write-Host "✗ DNS解析失败: $($_.Exception.Message)" -ForegroundColor Red
}

# 测试TCP连接
Write-Host "`n2. 测试TCP连接：" -ForegroundColor Yellow
try {
    $tcpTest = Test-NetConnection registry-1.docker.io -Port 443 -WarningAction SilentlyContinue
    if ($tcpTest.TcpTestSucceeded) {
        Write-Host "✓ TCP连接成功" -ForegroundColor Green
    } else {
        Write-Host "✗ TCP连接失败" -ForegroundColor Red
    }
} catch {
    Write-Host "✗ TCP测试异常: $($_.Exception.Message)" -ForegroundColor Red
}

# 测试HTTP连接
Write-Host "`n3. 测试HTTP连接：" -ForegroundColor Yellow
try {
    $webRequest = Invoke-WebRequest -Uri "https://registry-1.docker.io/v2/" -TimeoutSec 10 -ErrorAction Stop
    Write-Host "✓ HTTP连接成功，状态码: $($webRequest.StatusCode)" -ForegroundColor Green
} catch {
    Write-Host "✗ HTTP连接失败: $($_.Exception.Message)" -ForegroundColor Red
}

# 检查当前Docker代理配置
Write-Host "`n4. 当前Docker代理配置：" -ForegroundColor Yellow
docker info | Select-String -Pattern "Proxy"

# 建议
Write-Host "`n=== 建议 ===" -ForegroundColor Cyan
if ($tcpTest.TcpTestSucceeded -and $webRequest.StatusCode -eq 200) {
    Write-Host "网络连接正常，可以跳过代理配置" -ForegroundColor Green
    Write-Host "直接运行: docker-compose build" -ForegroundColor White
} else {
    Write-Host "网络连接存在问题，建议配置代理或使用国内镜像" -ForegroundColor Yellow
    Write-Host "可选方案：" -ForegroundColor White
    Write-Host "1. 运行 configure_china_mirror.ps1 （国内镜像加速）" -ForegroundColor White
    Write-Host "2. 运行 configure_docker_proxy.ps1 （自定义代理）" -ForegroundColor White
}