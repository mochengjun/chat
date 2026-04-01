# ============================================================
# 服务连通性验证脚本 (Windows版本)
# 服务器IP: 8.130.55.126
# 在部署完成后运行此脚本验证所有服务
# ============================================================

param(
    [string]$ServerIP = "8.130.55.126"
)

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "服务连通性验证测试" -ForegroundColor Cyan
Write-Host "服务器IP: $ServerIP" -ForegroundColor Cyan
Write-Host "测试时间: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# 测试计数
$passed = 0
$failed = 0

# 端口连通性测试
function Test-Port {
    param([string]$Host, [int]$Port, [string]$ServiceName)

    Write-Host "测试 $ServiceName (端口 $Port)..." -NoNewline

    try {
        $tcp = New-Object System.Net.Sockets.TcpClient
        $connect = $tcp.BeginConnect($Host, $Port, $null, $null)
        $wait = $connect.AsyncWaitHandle.WaitOne(5000, $false)

        if ($wait -and $tcp.Connected) {
            Write-Host " [通过]" -ForegroundColor Green
            $tcp.Close()
            return $true
        } else {
            Write-Host " [失败]" -ForegroundColor Red
            return $false
        }
    } catch {
        Write-Host " [失败]" -ForegroundColor Red
        return $false
    }
}

# HTTP服务测试
function Test-HttpService {
    param([string]$Url, [string]$ServiceName)

    Write-Host "测试 $ServiceName..." -NoNewline

    try {
        $response = Invoke-WebRequest -Uri $Url -TimeoutSec 10 -UseBasicParsing -ErrorAction Stop
        Write-Host " [通过] 状态码: $($response.StatusCode)" -ForegroundColor Green
        return $true
    } catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        if ($statusCode -in @(401, 403, 404)) {
            Write-Host " [通过] 状态码: $statusCode (服务响应)" -ForegroundColor Green
            return $true
        }
        Write-Host " [失败] 错误: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# WebSocket测试
function Test-WebSocket {
    param([string]$Url, [string]$ServiceName)

    Write-Host "测试 $ServiceName..." -NoNewline

    try {
        # 使用curl测试WebSocket升级
        $result = curl -s -o NUL -w "%{http_code}" --connect-timeout 10 `
            -H "Connection: Upgrade" `
            -H "Upgrade: websocket" `
            -H "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==" `
            -H "Sec-WebSocket-Version: 13" `
            $Url 2>$null

        if ($result -eq 101) {
            Write-Host " [通过] 升级成功 (101)" -ForegroundColor Green
            return $true
        } elseif ($result -in @(400, 401)) {
            Write-Host " [通过] 服务响应 ($result)" -ForegroundColor Green
            return $true
        } else {
            Write-Host " [失败] 状态码: $result" -ForegroundColor Red
            return $false
        }
    } catch {
        Write-Host " [失败] 错误: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Docker服务测试
function Test-DockerServices {
    Write-Host "检查Docker容器状态..." -NoNewline

    try {
        $containers = docker ps --format "{{.Names}}: {{.Status}}" 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host " [通过]" -ForegroundColor Green
            Write-Host ""
            Write-Host "运行中的容器:" -ForegroundColor Gray
            $containers | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
            return $true
        }
    } catch {}

    Write-Host " [失败] Docker未运行或未安装" -ForegroundColor Red
    return $false
}

# ==================== 执行测试 ====================

Write-Host "=== 1. 端口连通性测试 ===" -ForegroundColor Yellow
Write-Host ""

if (Test-Port -Host $ServerIP -Port 22 -ServiceName "SSH") { $passed++ } else { $failed++ }
if (Test-Port -Host $ServerIP -Port 80 -ServiceName "HTTP") { $passed++ } else { $failed++ }
if (Test-Port -Host $ServerIP -Port 443 -ServiceName "HTTPS") { $passed++ } else { $failed++ }
if (Test-Port -Host $ServerIP -Port 8081 -ServiceName "API") { $passed++ } else { $failed++ }

Write-Host ""
Write-Host "=== 2. HTTP服务测试 ===" -ForegroundColor Yellow
Write-Host ""

if (Test-HttpService -Url "http://$ServerIP/health" -ServiceName "API健康检查 (通过Nginx)") { $passed++ } else { $failed++ }
if (Test-HttpService -Url "http://$ServerIP:8081/health" -ServiceName "API健康检查 (直接访问)") { $passed++ } else { $failed++ }
if (Test-HttpService -Url "http://$ServerIP/nginx-health" -ServiceName "Nginx健康检查") { $passed++ } else { $failed++ }
if (Test-HttpService -Url "http://$ServerIP/api/v1/" -ServiceName "API根路径") { $passed++ } else { $failed++ }

Write-Host ""
Write-Host "=== 3. WebSocket测试 ===" -ForegroundColor Yellow
Write-Host ""

if (Test-WebSocket -Url "http://$ServerIP/api/v1/ws" -ServiceName "WebSocket升级测试") { $passed++ } else { $failed++ }

Write-Host ""
Write-Host "=== 4. Docker服务状态 ===" -ForegroundColor Yellow
Write-Host ""

if (Test-DockerServices) { $passed++ } else { $failed++ }

Write-Host ""
Write-Host "=== 5. 本地服务测试 (在服务器上运行) ===" -ForegroundColor Yellow
Write-Host ""

Write-Host "测试本地健康检查..." -NoNewline
try {
    $localHealth = Invoke-WebRequest -Uri "http://localhost/health" -TimeoutSec 5 -UseBasicParsing -ErrorAction Stop
    Write-Host " [通过]" -ForegroundColor Green
    $passed++
} catch {
    Write-Host " [跳过] 仅在服务器上运行" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "测试结果汇总" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "通过: $passed" -ForegroundColor Green
Write-Host "失败: $failed" -ForegroundColor Red
Write-Host ""

if ($failed -eq 0) {
    Write-Host "所有测试通过! 服务运行正常。" -ForegroundColor Green
    Write-Host ""
    Write-Host "访问地址:" -ForegroundColor White
    Write-Host "  主页:     http://$ServerIP" -ForegroundColor Cyan
    Write-Host "  API:      http://$ServerIP:8081" -ForegroundColor Cyan
    Write-Host "  健康检查: http://$ServerIP/health" -ForegroundColor Cyan
    Write-Host "  WebSocket: ws://$ServerIP/api/v1/ws" -ForegroundColor Cyan
    exit 0
} else {
    Write-Host "部分测试失败，请检查服务配置。" -ForegroundColor Red
    Write-Host ""
    Write-Host "排查建议:" -ForegroundColor Yellow
    Write-Host "  1. 检查Docker服务: docker ps" -ForegroundColor Gray
    Write-Host "  2. 查看容器日志: docker compose logs" -ForegroundColor Gray
    Write-Host "  3. 检查防火墙: Get-NetFirewallRule | Where-Object {\$_.Enabled -eq 'True'}" -ForegroundColor Gray
    Write-Host "  4. 检查阿里云安全组是否开放端口" -ForegroundColor Gray
    exit 1
}
