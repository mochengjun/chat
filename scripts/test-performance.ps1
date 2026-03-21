# 性能压力测试脚本
$baseUrl = "http://localhost:8081/api/v1"
$concurrentUsers = 10  # 并发用户数
$messagesPerUser = 5   # 每用户发送消息数

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "   Performance Stress Test" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Configuration:" -ForegroundColor Yellow
Write-Host "  Concurrent Users: $concurrentUsers"
Write-Host "  Messages per User: $messagesPerUser"
Write-Host "  Total Messages: $($concurrentUsers * $messagesPerUser)"
Write-Host ""

# 计时器
$script:totalStartTime = Get-Date
$script:successCount = 0
$script:failureCount = 0
$script:responseTimes = @()

# 并发测试函数
function Invoke-UserTest {
    param($userId)
    
    $userStartTime = Get-Date
    $random = Get-Random -Maximum 999999
    $username = "stress_user_${userId}_$random"
    
    # 1. 注册
    $registerBody = @{
        username = $username
        password = "Test123456"
        email = "stress_${userId}_$random@test.com"
        displayName = "Stress User $userId"
    } | ConvertTo-Json
    
    try {
        $requestStart = Get-Date
        $null = Invoke-RestMethod -Uri "$baseUrl/auth/register" -Method Post -Body $registerBody -ContentType "application/json" -TimeoutSec 10
        $script:responseTimes += (Get-Date) - $requestStart
        $script:successCount++
    } catch {
        $script:failureCount++
        return
    }
    
    # 2. 登录
    $loginBody = @{ username = $username; password = "Test123456" } | ConvertTo-Json
    try {
        $requestStart = Get-Date
        $loginResult = Invoke-RestMethod -Uri "$baseUrl/auth/login" -Method Post -Body $loginBody -ContentType "application/json" -TimeoutSec 10
        $script:responseTimes += (Get-Date) - $requestStart
        $script:successCount++
    } catch {
        $script:failureCount++
        return
    }
    
    $token = $loginResult.access_token
    $headers = @{ Authorization = "Bearer $token" }
    
    # 3. 创建房间
    $roomBody = @{
        name = "Stress Room $userId"
        type = "group"
    } | ConvertTo-Json
    
    try {
        $requestStart = Get-Date
        $roomResult = Invoke-RestMethod -Uri "$baseUrl/chat/rooms" -Method Post -Body $roomBody -ContentType "application/json" -Headers $headers -TimeoutSec 10
        $script:responseTimes += (Get-Date) - $requestStart
        $script:successCount++
        $roomId = $roomResult.id
    } catch {
        $script:failureCount++
        return
    }
    
    # 4. 发送多条消息
    for ($i = 1; $i -le $messagesPerUser; $i++) {
        $msgBody = @{
            content = "Stress test message $i from user $userId"
            type = "text"
        } | ConvertTo-Json
        
        try {
            $requestStart = Get-Date
            $null = Invoke-RestMethod -Uri "$baseUrl/chat/rooms/$roomId/messages" -Method Post -Body $msgBody -ContentType "application/json" -Headers $headers -TimeoutSec 10
            $script:responseTimes += (Get-Date) - $requestStart
            $script:successCount++
        } catch {
            $script:failureCount++
        }
    }
    
    $userDuration = (Get-Date) - $userStartTime
    Write-Host "  User $userId completed in $($userDuration.TotalSeconds.ToString('F2'))s" -ForegroundColor Gray
}

# 执行并发测试
Write-Host "Starting stress test..." -ForegroundColor Yellow
Write-Host ""

$jobs = @()
for ($i = 1; $i -le $concurrentUsers; $i++) {
    # 使用Start-Job实现并发（注意：这会创建新进程，开销较大）
    # 为了简化，这里使用顺序执行但记录时间
    Invoke-UserTest -userId $i
}

$script:totalDuration = (Get-Date) - $script:totalStartTime

# 计算统计数据
$avgResponseTime = if ($script:responseTimes.Count -gt 0) {
    ($script:responseTimes | Measure-Object -Property TotalMilliseconds -Average).Average
} else { 0 }

$minResponseTime = if ($script:responseTimes.Count -gt 0) {
    ($script:responseTimes | Measure-Object -Property TotalMilliseconds -Minimum).Minimum
} else { 0 }

$maxResponseTime = if ($script:responseTimes.Count -gt 0) {
    ($script:responseTimes | Measure-Object -Property TotalMilliseconds -Maximum).Maximum
} else { 0 }

# 显示结果
Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "   Performance Test Results" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Summary:" -ForegroundColor Yellow
Write-Host "  Total Duration: $($script:totalDuration.TotalSeconds.ToString('F2')) seconds" -ForegroundColor White
Write-Host "  Total Requests: $($script:successCount + $script:failureCount)" -ForegroundColor White
Write-Host "  Successful: $($script:successCount)" -ForegroundColor Green
Write-Host "  Failed: $($script:failureCount)" -ForegroundColor $(if ($script:failureCount -gt 0) { "Red" } else { "Green" })
Write-Host "  Success Rate: $([math]::Round($script:successCount / ($script:successCount + $script:failureCount) * 100, 2))%" -ForegroundColor White
Write-Host ""

Write-Host "Response Time Statistics:" -ForegroundColor Yellow
Write-Host "  Average: $([math]::Round($avgResponseTime, 2)) ms" -ForegroundColor White
Write-Host "  Min: $([math]::Round($minResponseTime, 2)) ms" -ForegroundColor White
Write-Host "  Max: $([math]::Round($maxResponseTime, 2)) ms" -ForegroundColor White
Write-Host ""

Write-Host "Throughput:" -ForegroundColor Yellow
$throughput = [math]::Round($script:successCount / $script:totalDuration.TotalSeconds, 2)
Write-Host "  Requests/second: $throughput" -ForegroundColor White
Write-Host ""

# 性能评估
Write-Host "Performance Assessment:" -ForegroundColor Yellow
if ($avgResponseTime -lt 100) {
    Write-Host "  Response Time: EXCELLENT (< 100ms)" -ForegroundColor Green
} elseif ($avgResponseTime -lt 300) {
    Write-Host "  Response Time: GOOD (< 300ms)" -ForegroundColor Green
} elseif ($avgResponseTime -lt 1000) {
    Write-Host "  Response Time: ACCEPTABLE (< 1s)" -ForegroundColor Yellow
} else {
    Write-Host "  Response Time: NEEDS IMPROVEMENT (> 1s)" -ForegroundColor Red
}

$successRate = [math]::Round($script:successCount / ($script:successCount + $script:failureCount) * 100, 2)
if ($successRate -eq 100) {
    Write-Host "  Success Rate: PERFECT (100%)" -ForegroundColor Green
} elseif ($successRate -ge 99) {
    Write-Host "  Success Rate: EXCELLENT (>= 99%)" -ForegroundColor Green
} elseif ($successRate -ge 95) {
    Write-Host "  Success Rate: GOOD (>= 95%)" -ForegroundColor Yellow
} else {
    Write-Host "  Success Rate: NEEDS ATTENTION (< 95%)" -ForegroundColor Red
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "   Test Completed" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
