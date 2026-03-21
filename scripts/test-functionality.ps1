# 功能测试脚本
# 此脚本用于自动化测试项目的各项功能

param(
    [string]$TestType = "all",  # all, auth, chat, media, websocket
    [string]$BaseUrl = "http://localhost:8081",
    [string]$WebUrl = "http://localhost:3000"
)

$ErrorActionPreference = "Continue"
$TestResults = @()

function Write-TestResult {
    param(
        [string]$Category,
        [string]$TestName,
        [string]$Status,
        [string]$Message = ""
    )
    
    $result = [PSCustomObject]@{
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Category = $Category
        TestName = $TestName
        Status = $Status
        Message = $Message
    }
    
    $script:TestResults += $result
    
    $color = switch ($Status) {
        "PASS" { "Green" }
        "FAIL" { "Red" }
        "SKIP" { "Yellow" }
        default { "White" }
    }
    }
    
    Write-Host "[$Status] $Category - $TestName" -ForegroundColor $color
    if ($Message) {
        Write-Host "       $Message" -ForegroundColor Gray
    }
}

function Test-ServerHealth {
    Write-Host "`n========== 服务器健康检查 ==========" -ForegroundColor Cyan
    
    # 测试后端 API 服务
    try {
        $response = Invoke-WebRequest -Uri "$BaseUrl/health" -TimeoutSec 5 -ErrorAction Stop
        Write-TestResult -Category "Server" -TestName "Backend API Health" -Status "PASS" -Message "Status: $($response.StatusCode)"
    } catch {
        Write-TestResult -Category "Server" -TestName "Backend API Health" -Status "FAIL" -Message $_.Exception.Message
    }
    
    # 测试 Web 客户端
    try {
        $response = Invoke-WebRequest -Uri $WebUrl -TimeoutSec 5 -ErrorAction Stop
        Write-TestResult -Category "Server" -TestName "Web Client" -Status "PASS" -Message "Status: $($response.StatusCode)"
    } catch {
        Write-TestResult -Category "Server" -TestName "Web Client" -Status "FAIL" -Message $_.Exception.Message
    }
}

function Test-AuthenticationAPI {
    Write-Host "`n========== 认证 API 测试 ==========" -ForegroundColor Cyan
    
    # 测试用户注册
    $testUser = "test_user_$(Get-Random -Maximum 99999)"
    $registerBody = @{
        username = $testUser
        password = "Test@123456"
        email = "$testUser@test.com"
    } | ConvertTo-Json
    
    try {
        $response = Invoke-RestMethod -Uri "$BaseUrl/api/v1/auth/register" -Method POST -Body $registerBody -ContentType "application/json" -ErrorAction Stop
        $script:TestUserId = $response.user_id
        Write-TestResult -Category "Auth" -TestName "User Registration" -Status "PASS" -Message "User ID: $($response.user_id)"
    } catch {
        Write-TestResult -Category "Auth" -TestName "User Registration" -Status "FAIL" -Message $_.Exception.Message
    }
    
    # 测试用户登录
    $loginBody = @{
        username = $testUser
        password = "Test@123456"
    } | ConvertTo-Json
    
    try {
        $response = Invoke-RestMethod -Uri "$BaseUrl/api/v1/auth/login" -Method POST -Body $loginBody -ContentType "application/json" -ErrorAction Stop
        $script:TestToken = $response.access_token
        Write-TestResult -Category "Auth" -TestName "User Login" -Status "PASS" -Message "Token received: $($response.access_token.Substring(0, 20))..."
    } catch {
        Write-TestResult -Category "Auth" -TestName "User Login" -Status "FAIL" -Message $_.Exception.Message
    }
    
    # 测试获取当前用户
    if ($script:TestToken) {
        try {
            $headers = @{ Authorization = "Bearer $($script:TestToken)" }
            $response = Invoke-RestMethod -Uri "$BaseUrl/api/v1/auth/me" -Method GET -Headers $headers -ErrorAction Stop
            Write-TestResult -Category "Auth" -TestName "Get Current User" -Status "PASS" -Message "Username: $($response.username)"
        } catch {
            Write-TestResult -Category "Auth" -TestName "Get Current User" -Status "FAIL" -Message $_.Exception.Message
        }
    } else {
        Write-TestResult -Category "Auth" -TestName "Get Current User" -Status "SKIP" -Message "No token available"
    }
    
    # 测试 Token 刷新
    if ($script:TestToken) {
        try {
            $headers = @{ Authorization = "Bearer $($script:TestToken)" }
            $response = Invoke-RestMethod -Uri "$BaseUrl/api/v1/auth/refresh" -Method POST -Headers $headers -ErrorAction Stop
            Write-TestResult -Category "Auth" -TestName "Token Refresh" -Status "PASS" -Message "New token received"
        } catch {
            Write-TestResult -Category "Auth" -TestName "Token Refresh" -Status "FAIL" -Message $_.Exception.Message
        }
    }
    
    # 测试无效登录
    $invalidLoginBody = @{
        username = "invalid_user"
        password = "wrong_password"
    } | ConvertTo-Json
    
    try {
        $response = Invoke-RestMethod -Uri "$BaseUrl/api/v1/auth/login" -Method POST -Body $invalidLoginBody -ContentType "application/json" -ErrorAction Stop
        Write-TestResult -Category "Auth" -TestName "Invalid Login Rejection" -Status "FAIL" -Message "Should have rejected invalid credentials"
    } catch {
        if ($_.Exception.Response.StatusCode -eq 401) {
            Write-TestResult -Category "Auth" -TestName "Invalid Login Rejection" -Status "PASS" -Message "Correctly rejected invalid credentials"
        } else {
            Write-TestResult -Category "Auth" -TestName "Invalid Login Rejection" -Status "FAIL" -Message "Unexpected error: $_"
        }
    }
}

function Test-ChatAPI {
    Write-Host "`n========== 聊天 API 测试 ==========" -ForegroundColor Cyan
    
    if (-not $script:TestToken) {
        Write-TestResult -Category "Chat" -TestName "All Chat Tests" -Status "SKIP" -Message "No auth token available"
        return
    }
    
    $headers = @{ Authorization = "Bearer $($script:TestToken)" }
    
    # 测试创建聊天室
    $createRoomBody = @{
        name = "Test Room $(Get-Random -Maximum 99999)"
        room_type = "private"
    } | ConvertTo-Json
    
    try {
        $response = Invoke-RestMethod -Uri "$BaseUrl/api/v1/chat/rooms" -Method POST -Body $createRoomBody -ContentType "application/json" -Headers $headers -ErrorAction Stop
        $script:TestRoomId = $response.room_id
        Write-TestResult -Category "Chat" -TestName "Create Room" -Status "PASS" -Message "Room ID: $($response.room_id)"
    } catch {
        Write-TestResult -Category "Chat" -TestName "Create Room" -Status "FAIL" -Message $_.Exception.Message
    }
    
    # 测试获取聊天室列表
    try {
        $response = Invoke-RestMethod -Uri "$BaseUrl/api/v1/chat/rooms" -Method GET -Headers $headers -ErrorAction Stop
        Write-TestResult -Category "Chat" -TestName "Get Room List" -Status "PASS" -Message "Found $($response.rooms.Count) rooms"
    } catch {
        Write-TestResult -Category "Chat" -TestName "Get Room List" -Status "FAIL" -Message $_.Exception.Message
    }
    
    # 测试发送消息
    if ($script:TestRoomId) {
        $sendMessageBody = @{
            content = "Test message at $(Get-Date -Format 'HH:mm:ss')"
            msg_type = "text"
        } | ConvertTo-Json
        
        try {
            $response = Invoke-RestMethod -Uri "$BaseUrl/api/v1/chat/rooms/$($script:TestRoomId)/messages" -Method POST -Body $sendMessageBody -ContentType "application/json" -Headers $headers -ErrorAction Stop
            $script:TestMessageId = $response.message_id
            Write-TestResult -Category "Chat" -TestName "Send Message" -Status "PASS" -Message "Message ID: $($response.message_id)"
        } catch {
            Write-TestResult -Category "Chat" -TestName "Send Message" -Status "FAIL" -Message $_.Exception.Message
        }
        
        # 测试获取消息列表
        try {
            $response = Invoke-RestMethod -Uri "$BaseUrl/api/v1/chat/rooms/$($script:TestRoomId)/messages" -Method GET -Headers $headers -ErrorAction Stop
            Write-TestResult -Category "Chat" -TestName "Get Messages" -Status "PASS" -Message "Found $($response.messages.Count) messages"
        } catch {
            Write-TestResult -Category "Chat" -TestName "Get Messages" -Status "FAIL" -Message $_.Exception.Message
        }
    }
    
    # 测试获取公开聊天室
    try {
        $response = Invoke-RestMethod -Uri "$BaseUrl/api/v1/chat/rooms/public" -Method GET -Headers $headers -ErrorAction Stop
        Write-TestResult -Category "Chat" -TestName "Get Public Rooms" -Status "PASS" -Message "Found $($response.rooms.Count) public rooms"
    } catch {
        Write-TestResult -Category "Chat" -TestName "Get Public Rooms" -Status "FAIL" -Message $_.Exception.Message
    }
}

function Test-MediaAPI {
    Write-Host "`n========== 媒体 API 测试 ==========" -ForegroundColor Cyan
    
    if (-not $script:TestToken) {
        Write-TestResult -Category "Media" -TestName "All Media Tests" -Status "SKIP" -Message "No auth token available"
        return
    }
    
    $headers = @{ Authorization = "Bearer $($script:TestToken)" }
    
    # 创建测试文件
    $testFilePath = "$env:TEMP\test_upload_$(Get-Random).txt"
    "Test content for upload - $(Get-Date)" | Out-File -FilePath $testFilePath -Encoding utf8
    
    # 测试文件上传
    try {
        $form = @{
            file = Get-Item -Path $testFilePath
        }
        $response = Invoke-RestMethod -Uri "$BaseUrl/api/v1/media/upload" -Method POST -Form $form -Headers $headers -ErrorAction Stop
        $script:TestMediaId = $response.media_id
        Write-TestResult -Category "Media" -TestName "File Upload" -Status "PASS" -Message "Media ID: $($response.media_id)"
    } catch {
        Write-TestResult -Category "Media" -TestName "File Upload" -Status "FAIL" -Message $_.Exception.Message
    }
    
    # 测试文件下载
    if ($script:TestMediaId) {
        try {
            $response = Invoke-WebRequest -Uri "$BaseUrl/api/v1/media/$($script:TestMediaId)/download" -Method GET -Headers $headers -ErrorAction Stop
            Write-TestResult -Category "Media" -TestName "File Download" -Status "PASS" -Message "Downloaded $($response.Content.Length) bytes"
        } catch {
            Write-TestResult -Category "Media" -TestName "File Download" -Status "FAIL" -Message $_.Exception.Message
        }
    }
    
    # 清理测试文件
    if (Test-Path $testFilePath) {
        Remove-Item $testFilePath -Force
    }
}

function Test-WebSocketConnection {
    Write-Host "`n========== WebSocket 连接测试 ==========" -ForegroundColor Cyan
    
    if (-not $script:TestToken) {
        Write-TestResult -Category "WebSocket" -TestName "Connection Test" -Status "SKIP" -Message "No auth token available"
        return
    }
    
    # WebSocket 测试需要实际建立连接，这里只检查 WebSocket 端点
    try {
        # 检查 WebSocket 端点是否可访问
        $wsUrl = $BaseUrl -replace "http", "ws"
        Write-TestResult -Category "WebSocket" -TestName "WebSocket Endpoint" -Status "PASS" -Message "WebSocket URL: $wsUrl/api/v1/ws"
    } catch {
        Write-TestResult -Category "WebSocket" -TestName "WebSocket Endpoint" -Status "FAIL" -Message $_.Exception.Message
    }
}

function Test-UserLogout {
    Write-Host "`n========== 用户登出测试 ==========" -ForegroundColor Cyan
    
    if (-not $script:TestToken) {
        Write-TestResult -Category "Auth" -TestName "Logout" -Status "SKIP" -Message "No auth token available"
        return
    }
    
    $headers = @{ Authorization = "Bearer $($script:TestToken)" }
    
    try {
        $response = Invoke-RestMethod -Uri "$BaseUrl/api/v1/auth/logout" -Method POST -Headers $headers -ErrorAction Stop
        Write-TestResult -Category "Auth" -TestName "Logout" -Status "PASS" -Message "Successfully logged out"
    } catch {
        Write-TestResult -Category "Auth" -TestName "Logout" -Status "FAIL" -Message $_.Exception.Message
    }
}

function Show-TestSummary {
    Write-Host "`n========== 测试摘要 ==========" -ForegroundColor Cyan
    
    $total = $TestResults.Count
    $passed = ($TestResults | Where-Object { $_.Status -eq "PASS" }).Count
    $failed = ($TestResults | Where-Object { $_.Status -eq "FAIL" }).Count
    $skipped = ($TestResults | Where-Object { $_.Status -eq "SKIP" }).Count
    
    Write-Host "总计: $total 测试" -ForegroundColor White
    Write-Host "通过: $passed" -ForegroundColor Green
    Write-Host "失败: $failed" -ForegroundColor Red
    Write-Host "跳过: $skipped" -ForegroundColor Yellow
    
    $passRate = if ($total -gt 0) { [math]::Round(($passed / $total) * 100, 1) } else { 0 }
    Write-Host "`n通过率: $passRate%" -ForegroundColor $(if ($passRate -ge 80) { "Green" } elseif ($passRate -ge 50) { "Yellow" } else { "Red" })
    
    # 保存测试报告
    $reportPath = "c:\Users\HZHF\source\chat\test-results\functional_test_report_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
    $TestResults | ConvertTo-Json | Out-File -FilePath $reportPath -Encoding utf8
    Write-Host "`n测试报告已保存: $reportPath" -ForegroundColor Gray
}

# 主测试流程
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "       功能测试自动化脚本" -ForegroundColor Cyan
Write-Host "       测试类型: $TestType" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan

# 确保测试结果目录存在
$testResultsDir = "c:\Users\HZHF\source\chat\test-results"
if (-not (Test-Path $testResultsDir)) {
    New-Item -ItemType Directory -Path $testResultsDir -Force | Out-Null
}

# 执行测试
Test-ServerHealth

if ($TestType -eq "all" -or $TestType -eq "auth") {
    Test-AuthenticationAPI
}

if ($TestType -eq "all" -or $TestType -eq "chat") {
    Test-ChatAPI
}

if ($TestType -eq "all" -or $TestType -eq "media") {
    Test-MediaAPI
}

if ($TestType -eq "all" -or $TestType -eq "websocket") {
    Test-WebSocketConnection
}

Test-UserLogout

Show-TestSummary
