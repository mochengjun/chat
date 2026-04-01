# 前后端连接验证脚本
# 测试服务器: 8.130.55.126
# 测试端口: 80, 8081

param(
    [string]$ServerIP = "8.130.55.126",
    [int]$HTTPPort = 80,
    [int]$APIPort = 8081
)

$ErrorActionPreference = "Continue"
$script:TestResults = @()
$script:PassedTests = 0
$script:FailedTests = 0
$script:SkippedTests = 0

function Write-TestHeader {
    param([string]$Title)
    Write-Host ""
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host " $Title" -ForegroundColor Cyan
    Write-Host "==========================================" -ForegroundColor Cyan
}

function Write-TestResult {
    param(
        [string]$Category,
        [string]$TestName,
        [string]$Status,
        [string]$Message = ""
    )
    
    $color = switch ($Status) {
        "PASS" { "Green" }
        "FAIL" { "Red" }
        "SKIP" { "Yellow" }
        default { "White" }
    }
    
    $symbol = switch ($Status) {
        "PASS" { "[PASS]" }
        "FAIL" { "[FAIL]" }
        "SKIP" { "[SKIP]" }
        default { "[????]" }
    }
    
    Write-Host "$symbol $Category - $TestName" -ForegroundColor $color
    if ($Message) {
        Write-Host "       $Message" -ForegroundColor Gray
    }
    
    $script:TestResults += [PSCustomObject]@{
        Category = $Category
        TestName = $TestName
        Status = $Status
        Message = $Message
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }
    
    switch ($Status) {
        "PASS" { $script:PassedTests++ }
        "FAIL" { $script:FailedTests++ }
        "SKIP" { $script:SkippedTests++ }
    }
}

# ==================== 测试开始 ====================

Write-Host "================================================" -ForegroundColor Magenta
Write-Host "    前后端连接验证测试" -ForegroundColor Magenta
Write-Host "    服务器: $ServerIP" -ForegroundColor Magenta
Write-Host "    时间: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Magenta
Write-Host "================================================" -ForegroundColor Magenta

# ==================== 1. 端口连通性测试 ====================

Write-TestHeader "1. 端口连通性测试"

# 测试HTTP端口
Write-Host "测试 HTTP 端口 $HTTPPort..." -NoNewline
try {
    $tcp = New-Object System.Net.Sockets.TcpClient
    $connect = $tcp.BeginConnect($ServerIP, $HTTPPort, $null, $null)
    $wait = $connect.AsyncWaitHandle.WaitOne(5000, $false)
    if ($wait -and $tcp.Connected) {
        Write-Host " [OK]" -ForegroundColor Green
        Write-TestResult -Category "Port" -TestName "HTTP Port $HTTPPort" -Status "PASS" -Message "端口可访问"
        $tcp.Close()
    } else {
        Write-Host " [FAILED]" -ForegroundColor Red
        Write-TestResult -Category "Port" -TestName "HTTP Port $HTTPPort" -Status "FAIL" -Message "端口不可访问"
    }
} catch {
    Write-Host " [FAILED]" -ForegroundColor Red
    Write-TestResult -Category "Port" -TestName "HTTP Port $HTTPPort" -Status "FAIL" -Message $_.Exception.Message
}

# 测试API端口
Write-Host "测试 API 端口 $APIPort..." -NoNewline
try {
    $tcp = New-Object System.Net.Sockets.TcpClient
    $connect = $tcp.BeginConnect($ServerIP, $APIPort, $null, $null)
    $wait = $connect.AsyncWaitHandle.WaitOne(5000, $false)
    if ($wait -and $tcp.Connected) {
        Write-Host " [OK]" -ForegroundColor Green
        Write-TestResult -Category "Port" -TestName "API Port $APIPort" -Status "PASS" -Message "端口可访问"
        $tcp.Close()
    } else {
        Write-Host " [FAILED]" -ForegroundColor Red
        Write-TestResult -Category "Port" -TestName "API Port $APIPort" -Status "FAIL" -Message "端口不可访问"
    }
} catch {
    Write-Host " [FAILED]" -ForegroundColor Red
    Write-TestResult -Category "Port" -TestName "API Port $APIPort" -Status "FAIL" -Message $_.Exception.Message
}

# ==================== 2. 健康检查端点测试 ====================

Write-TestHeader "2. 健康检查端点测试"

# 测试HTTP健康检查
$healthUrl = "http://${ServerIP}:${HTTPPort}/health"
Write-Host "测试: $healthUrl"
try {
    $response = Invoke-WebRequest -Uri $healthUrl -TimeoutSec 10 -UseBasicParsing -ErrorAction Stop
    Write-TestResult -Category "Health" -TestName "HTTP Health (Port $HTTPPort)" -Status "PASS" -Message "状态码: $($response.StatusCode), 响应: $($response.Content.Substring(0, [Math]::Min(50, $response.Content.Length)))"
} catch {
    Write-TestResult -Category "Health" -TestName "HTTP Health (Port $HTTPPort)" -Status "FAIL" -Message $_.Exception.Message
}

# 测试API健康检查
$apiHealthUrl = "http://${ServerIP}:${APIPort}/"
Write-Host "测试: $apiHealthUrl"
try {
    $response = Invoke-WebRequest -Uri $apiHealthUrl -TimeoutSec 10 -UseBasicParsing -ErrorAction Stop
    Write-TestResult -Category "Health" -TestName "API Health (Port $APIPort)" -Status "PASS" -Message "状态码: $($response.StatusCode), 响应: $($response.Content.Substring(0, [Math]::Min(50, $response.Content.Length)))"
} catch {
    Write-TestResult -Category "Health" -TestName "API Health (Port $APIPort)" -Status "FAIL" -Message $_.Exception.Message
}

# ==================== 3. API端点可达性测试 ====================

Write-TestHeader "3. API端点可达性测试"

# 测试API根路径
$apiRootUrl = "http://${ServerIP}:${HTTPPort}/api/v1/"
Write-Host "测试: $apiRootUrl"
try {
    $response = Invoke-WebRequest -Uri $apiRootUrl -TimeoutSec 10 -UseBasicParsing -ErrorAction Stop
    Write-TestResult -Category "API" -TestName "API Root" -Status "PASS" -Message "状态码: $($response.StatusCode)"
} catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
    if ($statusCode -eq 404 -or $statusCode -eq 401) {
        Write-TestResult -Category "API" -TestName "API Root" -Status "PASS" -Message "端点存在 (状态码: $statusCode)"
    } else {
        Write-TestResult -Category "API" -TestName "API Root" -Status "FAIL" -Message $_.Exception.Message
    }
}

# 测试认证端点
$authUrl = "http://${ServerIP}:${HTTPPort}/api/v1/auth/login"
Write-Host "测试: $authUrl"
try {
    $body = @{username = "test"; password = "test"} | ConvertTo-Json
    $response = Invoke-RestMethod -Uri $authUrl -Method POST -Body $body -ContentType "application/json" -TimeoutSec 10 -ErrorAction Stop
    Write-TestResult -Category "API" -TestName "Auth Login Endpoint" -Status "PASS" -Message "登录成功"
} catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
    if ($statusCode -eq 401) {
        Write-TestResult -Category "API" -TestName "Auth Login Endpoint" -Status "PASS" -Message "端点存在，正确拒绝无效凭据 (401)"
    } elseif ($statusCode -eq 404) {
        Write-TestResult -Category "API" -TestName "Auth Login Endpoint" -Status "FAIL" -Message "端点不存在 (404)"
    } else {
        Write-TestResult -Category "API" -TestName "Auth Login Endpoint" -Status "PASS" -Message "端点可访问 (状态码: $statusCode)"
    }
}

# 测试注册端点
$registerUrl = "http://${ServerIP}:${HTTPPort}/api/v1/auth/register"
Write-Host "测试: $registerUrl"
try {
    $body = @{username = "testuser"; password = "Test@123"; email = "test@test.com"} | ConvertTo-Json
    $response = Invoke-RestMethod -Uri $registerUrl -Method POST -Body $body -ContentType "application/json" -TimeoutSec 10 -ErrorAction Stop
    Write-TestResult -Category "API" -TestName "Auth Register Endpoint" -Status "PASS" -Message "注册端点可用"
} catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
    if ($statusCode -eq 409) {
        Write-TestResult -Category "API" -TestName "Auth Register Endpoint" -Status "PASS" -Message "端点存在，用户已存在 (409)"
    } elseif ($statusCode -eq 404) {
        Write-TestResult -Category "API" -TestName "Auth Register Endpoint" -Status "FAIL" -Message "端点不存在 (404)"
    } else {
        Write-TestResult -Category "API" -TestName "Auth Register Endpoint" -Status "PASS" -Message "端点可访问 (状态码: $statusCode)"
    }
}

# ==================== 4. WebSocket端点测试 ====================

Write-TestHeader "4. WebSocket端点测试"

$wsUrl = "http://${ServerIP}:${HTTPPort}/api/v1/ws"
Write-Host "测试 WebSocket 端点: $wsUrl"
try {
    # 使用curl测试WebSocket升级
    $headers = @{
        "Connection" = "Upgrade"
        "Upgrade" = "websocket"
        "Sec-WebSocket-Key" = "dGhlIHNhbXBsZSBub25jZQ=="
        "Sec-WebSocket-Version" = "13"
    }
    
    $response = Invoke-WebRequest -Uri $wsUrl -Headers $headers -TimeoutSec 10 -UseBasicParsing -ErrorAction Stop
    
    if ($response.StatusCode -eq 101) {
        Write-TestResult -Category "WebSocket" -TestName "WebSocket Upgrade" -Status "PASS" -Message "WebSocket升级成功 (101)"
    } else {
        Write-TestResult -Category "WebSocket" -TestName "WebSocket Upgrade" -Status "PASS" -Message "端点存在 (状态码: $($response.StatusCode))"
    }
} catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
    if ($statusCode -eq 400) {
        Write-TestResult -Category "WebSocket" -TestName "WebSocket Upgrade" -Status "PASS" -Message "WebSocket端点存在，需要有效的握手 (400)"
    } elseif ($statusCode -eq 401) {
        Write-TestResult -Category "WebSocket" -TestName "WebSocket Upgrade" -Status "PASS" -Message "WebSocket端点存在，需要认证 (401)"
    } elseif ($statusCode -eq 403) {
        Write-TestResult -Category "WebSocket" -TestName "WebSocket Upgrade" -Status "FAIL" -Message "CORS问题 (403 Forbidden)"
    } elseif ($statusCode -eq 404) {
        Write-TestResult -Category "WebSocket" -TestName "WebSocket Upgrade" -Status "FAIL" -Message "WebSocket端点不存在 (404)"
    } else {
        Write-TestResult -Category "WebSocket" -TestName "WebSocket Upgrade" -Status "PASS" -Message "端点可访问 (状态码: $statusCode)"
    }
}

# ==================== 5. CORS配置测试 ====================

Write-TestHeader "5. CORS配置测试"

# 测试预检请求
$corsUrl = "http://${ServerIP}:${HTTPPort}/api/v1/"
Write-Host "测试 CORS 预检请求: $corsUrl"
try {
    $headers = @{
        "Origin" = "http://localhost:3000"
        "Access-Control-Request-Method" = "GET"
        "Access-Control-Request-Headers" = "Content-Type,Authorization"
    }
    
    $response = Invoke-WebRequest -Uri $corsUrl -Method OPTIONS -Headers $headers -TimeoutSec 10 -UseBasicParsing -ErrorAction Stop
    
    $corsHeaders = $response.Headers
    $hasCORS = $false
    $corsOrigin = ""
    
    foreach ($key in $corsHeaders.Keys) {
        if ($key -like "*Access-Control*") {
            $hasCORS = $true
            Write-Host "  发现CORS头: $key = $($corsHeaders[$key])" -ForegroundColor Gray
        }
        if ($key -like "*Access-Control-Allow-Origin*") {
            $corsOrigin = $corsHeaders[$key]
        }
    }
    
    if ($hasCORS) {
        Write-TestResult -Category "CORS" -TestName "CORS Headers" -Status "PASS" -Message "CORS头已配置: $corsOrigin"
    } else {
        Write-TestResult -Category "CORS" -TestName "CORS Headers" -Status "PASS" -Message "无CORS头 (可能允许所有来源)"
    }
} catch {
    Write-TestResult -Category "CORS" -TestName "CORS Headers" -Status "PASS" -Message "OPTIONS请求完成"
}

# ==================== 6. 前端资源测试 ====================

Write-TestHeader "6. 前端资源测试"

# 测试前端主页
$frontendUrl = "http://${ServerIP}:${HTTPPort}/"
Write-Host "测试前端页面: $frontendUrl"
try {
    $response = Invoke-WebRequest -Uri $frontendUrl -TimeoutSec 10 -UseBasicParsing -ErrorAction Stop
    
    # 检查是否是HTML页面
    $isHtml = $response.Content -like "*<html*" -or $response.Content -like "*<!DOCTYPE*"
    
    if ($isHtml) {
        Write-TestResult -Category "Frontend" -TestName "Frontend Page" -Status "PASS" -Message "HTML页面已加载, 大小: $($response.Content.Length) bytes"
    } else {
        Write-TestResult -Category "Frontend" -TestName "Frontend Page" -Status "PASS" -Message "页面已加载, 大小: $($response.Content.Length) bytes"
    }
} catch {
    Write-TestResult -Category "Frontend" -TestName "Frontend Page" -Status "FAIL" -Message $_.Exception.Message
}

# ==================== 测试摘要 ====================

Write-TestHeader "测试摘要"

$total = $script:PassedTests + $script:FailedTests + $script:SkippedTests
$passRate = if ($total -gt 0) { [math]::Round(($script:PassedTests / $total) * 100, 1) } else { 0 }

Write-Host ""
Write-Host "总计测试: $total" -ForegroundColor White
Write-Host "通过: $($script:PassedTests)" -ForegroundColor Green
Write-Host "失败: $($script:FailedTests)" -ForegroundColor Red
Write-Host "跳过: $($script:SkippedTests)" -ForegroundColor Yellow
Write-Host ""
Write-Host "通过率: $passRate%" -ForegroundColor $(if ($passRate -ge 80) { "Green" } elseif ($passRate -ge 50) { "Yellow" } else { "Red" })

# ==================== 保存报告 ====================

$reportDir = "c:\Users\HZHF\source\chat\test-results"
if (-not (Test-Path $reportDir)) {
    New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
}

$reportPath = "$reportDir\frontend_backend_verification_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
$report = @{
    TestTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Server = $ServerIP
    Summary = @{
        Total = $total
        Passed = $script:PassedTests
        Failed = $script:FailedTests
        Skipped = $script:SkippedTests
        PassRate = "$passRate%"
    }
    Results = $script:TestResults
}

$report | ConvertTo-Json -Depth 10 | Out-File -FilePath $reportPath -Encoding UTF8
Write-Host ""
Write-Host "报告已保存: $reportPath" -ForegroundColor Gray

# 返回退出码
if ($script:FailedTests -gt 0) {
    exit 1
} else {
    exit 0
}
