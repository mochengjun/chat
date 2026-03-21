# ============================================================
# Secure Enterprise Chat - Mock Backend Server
# 模拟后端服务 - 用于端到端测试
# ============================================================

param(
    [Parameter()]
    [int]$Port = 8081,

    [Parameter()]
    [switch]$RunInBackground = $false
)

$ErrorActionPreference = "Continue"

# HTTP响应模板
function Get-HealthResponse {
    return @"
{"status":"ok","timestamp":"$(Get-Date -Format "o")","version":"1.0.0-test"}
"@
}

function Get-ApiResponse {
    param([string]$Path)

    switch -Regex ($Path) {
        "/api/v1/health" {
            return (Get-HealthResponse)
        }
        "/api/v1/auth/login" {
            return '{"access_token":"test_token_12345","refresh_token":"refresh_12345","expires_in":3600}'
        }
        "/api/v1/auth/register" {
            return '{"user_id":"user_123","username":"testuser","message":"User registered successfully"}'
        }
        "/api/v1/rooms" {
            return '[{"id":"room_1","name":"Test Room","last_message":"Hello","unread_count":0}]'
        }
        "/api/v1/messages/.*" {
            return '[{"id":"msg_1","content":"Test message","sender":"user_1","timestamp":"' + (Get-Date -Format "o") + '"}]'
        }
        default {
            return '{"message":"OK","path":"' + $Path + '"}'
        }
    }
}

# 创建HTTP监听器
function Start-MockServer {
    param([int]$Port)

    $listener = New-Object System.Net.HttpListener
    # 只绑定localhost，不需要管理员权限
    $listener.Prefixes.Add("http://localhost:$Port/")
    $listener.Prefixes.Add("http://127.0.0.1:$Port/")

    try {
        $listener.Start()
        Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Mock server started on port $Port" -ForegroundColor Green
        Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Health check: http://localhost:$Port/api/v1/health" -ForegroundColor Cyan

        # 创建PID文件
        $pid | Out-File -FilePath ".mock_server.pid" -Force

        while ($listener.IsListening) {
            try {
                $context = $listener.GetContext()
                $request = $context.Request
                $response = $context.Response

                $path = $request.Url.LocalPath
                $method = $request.HttpMethod

                Write-Host "[$(Get-Date -Format 'HH:mm:ss')] $method $path" -ForegroundColor Gray

                # 设置CORS头
                $response.Headers.Add("Access-Control-Allow-Origin", "*")
                $response.Headers.Add("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
                $response.Headers.Add("Access-Control-Allow-Headers", "Content-Type, Authorization")

                if ($method -eq "OPTIONS") {
                    $response.StatusCode = 200
                    $response.Close()
                    continue
                }

                # 生成响应
                $responseBody = Get-ApiResponse -Path $path
                $buffer = [System.Text.Encoding]::UTF8.GetBytes($responseBody)

                $response.ContentType = "application/json"
                $response.ContentLength64 = $buffer.Length
                $response.OutputStream.Write($buffer, 0, $buffer.Length)
                $response.OutputStream.Close()
            }
            catch {
                Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Error: $_" -ForegroundColor Red
            }
        }
    }
    catch {
        Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Failed to start server: $_" -ForegroundColor Red
    }
    finally {
        $listener.Stop()
        $listener.Close()
        Remove-Item -Path ".mock_server.pid" -Force -ErrorAction SilentlyContinue
        Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Mock server stopped" -ForegroundColor Yellow
    }
}

# 停止服务器
function Stop-MockServer {
    if (Test-Path ".mock_server.pid") {
        $pid = Get-Content ".mock_server.pid"
        try {
            Stop-Process -Id $pid -Force -ErrorAction SilentlyContinue
            Remove-Item -Path ".mock_server.pid" -Force
            Write-Host "Mock server stopped" -ForegroundColor Green
        }
        catch {
            Write-Host "Failed to stop server: $_" -ForegroundColor Red
        }
    }
}

# 检查服务器是否运行
function Test-ServerRunning {
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:$Port/api/v1/health" -Method GET -TimeoutSec 2 -ErrorAction SilentlyContinue
        return $response.StatusCode -eq 200
    }
    catch {
        return $false
    }
}

# 主逻辑
if ($RunInBackground) {
    # 在后台运行
    $job = Start-Job -ScriptBlock {
        param($Port)
        & $PSScriptRoot/mock_server.ps1 -Port $Port
    } -ArgumentList $Port

    # 等待服务器启动
    Start-Sleep -Seconds 2

    if (Test-ServerRunning) {
        Write-Host "Mock server is running in background on port $Port" -ForegroundColor Green
    }
    else {
        Write-Host "Failed to start mock server" -ForegroundColor Red
    }
}
else {
    # 前台运行
    Write-Host "Starting mock server... Press Ctrl+C to stop" -ForegroundColor Cyan
    Start-MockServer -Port $Port
}
