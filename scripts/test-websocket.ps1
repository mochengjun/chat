# WebSocket 测试脚本
# 使用 .NET WebSocket 类进行测试

Add-Type -AssemblyName System.Net.WebSockets

$wsUrl = "ws://localhost:8081/api/v1/ws"
$token = $args[0]

if (-not $token) {
    Write-Host "Usage: .\test-websocket.ps1 <access_token>" -ForegroundColor Red
    exit 1
}

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "   WebSocket Connection Test" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

# 构建带token的URL
$fullUrl = "$wsUrl`?token=$token"
Write-Host "Connecting to: $wsUrl ..." -ForegroundColor Yellow

try {
    # 创建 WebSocket 客户端
    $webSocket = New-Object System.Net.WebSockets.ClientWebSocket
    $cancellationToken = New-Object System.Threading.CancellationToken
    
    # 连接
    $uri = New-Object System.Uri($fullUrl)
    $connectTask = $webSocket.ConnectAsync($uri, $cancellationToken)
    $connectTask.Wait()
    
    if ($webSocket.State -eq "Open") {
        Write-Host "  [OK] WebSocket connected!" -ForegroundColor Green
        Write-Host ""
        
        # 发送心跳
        $pingMessage = '{"type":"ping","payload":{},"timestamp":"' + (Get-Date -Format "o") + '"}'
        $buffer = [System.Text.Encoding]::UTF8.GetBytes($pingMessage)
        $segment = New-Object System.ArraySegment[byte] -ArgumentList @(,$buffer)
        
        $sendTask = $webSocket.SendAsync($segment, [System.Net.WebSockets.WebSocketMessageType]::Text, $true, $cancellationToken)
        $sendTask.Wait()
        Write-Host "  Sent ping message" -ForegroundColor Yellow
        
        # 接收消息
        $receiveBuffer = New-Object byte[] 4096
        $receiveSegment = New-Object System.ArraySegment[byte] -ArgumentList @(,$receiveBuffer)
        
        Write-Host "  Waiting for response..." -ForegroundColor Yellow
        $receiveTask = $webSocket.ReceiveAsync($receiveSegment, $cancellationToken)
        
        if ($receiveTask.Wait(5000)) {
            $response = [System.Text.Encoding]::UTF8.GetString($receiveBuffer, 0, $receiveTask.Result.Count)
            Write-Host "  Received: $response" -ForegroundColor Green
        } else {
            Write-Host "  No response received within 5 seconds" -ForegroundColor Yellow
        }
        
        # 关闭连接
        $closeTask = $webSocket.CloseAsync([System.Net.WebSockets.WebSocketCloseStatus]::NormalClosure, "Test completed", $cancellationToken)
        $closeTask.Wait()
        Write-Host ""
        Write-Host "  [OK] Connection closed normally" -ForegroundColor Green
    } else {
        Write-Host "  [ERROR] WebSocket state: $($webSocket.State)" -ForegroundColor Red
    }
    
    $webSocket.Dispose()
} catch {
    Write-Host "  [ERROR] $_" -ForegroundColor Red
    Write-Host "  Details: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "   WebSocket Test Completed" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
