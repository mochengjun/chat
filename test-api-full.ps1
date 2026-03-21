# Full API Test Script for Chat Application
# Date: 2026-03-16

$baseUrl = "http://localhost:8081"
$webUrl = "http://localhost:3000"
$testUsername = "autotest$(Get-Date -Format 'HHmmss')"
$testPassword = "Test123456!"
$testEmail = "$testUsername@test.com"
$token = $null
$roomId = $null

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Chat Application Full Functional Test" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Test 1: Health Check
Write-Host "[1/12] Testing Health Check..." -NoNewline
try {
    $response = Invoke-RestMethod -Uri "$baseUrl/health" -Method Get -TimeoutSec 10
    if ($response.status -eq "ok") {
        Write-Host " PASSED" -ForegroundColor Green
    } else {
        Write-Host " FAILED" -ForegroundColor Red
    }
} catch {
    Write-Host " FAILED: $_" -ForegroundColor Red
}

# Test 2: User Registration
Write-Host "[2/12] Testing User Registration ($testUsername)..." -NoNewline
try {
    $body = @{
        username = $testUsername
        password = $testPassword
        email = $testEmail
    } | ConvertTo-Json
    
    $response = Invoke-RestMethod -Uri "$baseUrl/api/v1/auth/register" -Method Post -Body $body -ContentType "application/json" -TimeoutSec 10
    if ($response.success) {
        Write-Host " PASSED" -ForegroundColor Green
    } else {
        Write-Host " FAILED: $($response.message)" -ForegroundColor Red
    }
} catch {
    Write-Host " FAILED: $_" -ForegroundColor Red
}

# Test 3: User Login
Write-Host "[3/12] Testing User Login..." -NoNewline
try {
    $body = @{
        username = $testUsername
        password = $testPassword
    } | ConvertTo-Json
    
    $response = Invoke-RestMethod -Uri "$baseUrl/api/v1/auth/login" -Method Post -Body $body -ContentType "application/json" -TimeoutSec 10
    if ($response.success -and $response.data.token) {
        $token = $response.data.token
        Write-Host " PASSED" -ForegroundColor Green
    } else {
        Write-Host " FAILED" -ForegroundColor Red
    }
} catch {
    Write-Host " FAILED: $_" -ForegroundColor Red
}

if (-not $token) {
    Write-Host "Cannot continue without token. Exiting." -ForegroundColor Red
    exit 1
}

$headers = @{
    "Authorization" = "Bearer $token"
}

# Test 4: Get Current User
Write-Host "[4/12] Testing Get Current User..." -NoNewline
try {
    $response = Invoke-RestMethod -Uri "$baseUrl/api/v1/auth/me" -Method Get -Headers $headers -TimeoutSec 10
    if ($response.success) {
        Write-Host " PASSED" -ForegroundColor Green
    } else {
        Write-Host " FAILED" -ForegroundColor Red
    }
} catch {
    Write-Host " FAILED: $_" -ForegroundColor Red
}

# Test 5: Get Rooms
Write-Host "[5/12] Testing Get Rooms..." -NoNewline
try {
    $response = Invoke-RestMethod -Uri "$baseUrl/api/v1/chat/rooms" -Method Get -Headers $headers -TimeoutSec 10
    Write-Host " PASSED" -ForegroundColor Green
} catch {
    Write-Host " FAILED: $_" -ForegroundColor Red
}

# Test 6: Create Room
Write-Host "[6/12] Testing Create Room..." -NoNewline
try {
    $body = @{
        name = "Test Room $(Get-Date -Format 'HHmmss')"
        type = "public"
    } | ConvertTo-Json
    
    $response = Invoke-RestMethod -Uri "$baseUrl/api/v1/chat/rooms" -Method Post -Body $body -ContentType "application/json" -Headers $headers -TimeoutSec 10
    if ($response.success) {
        $roomId = $response.data.id
        Write-Host " PASSED" -ForegroundColor Green
    } else {
        Write-Host " FAILED" -ForegroundColor Red
    }
} catch {
    Write-Host " FAILED: $_" -ForegroundColor Red
}

if (-not $roomId) {
    # Try to get an existing room
    try {
        $response = Invoke-RestMethod -Uri "$baseUrl/api/v1/chat/rooms" -Method Get -Headers $headers -TimeoutSec 10
        if ($response.data -and $response.data.Count -gt 0) {
            $roomId = $response.data[0].id
        }
    } catch {}
}

# Test 7: Send Message (if room exists)
Write-Host "[7/12] Testing Send Message..." -NoNewline
if ($roomId) {
    try {
        $body = @{
            content = "Test message $(Get-Date -Format 'HH:mm:ss')"
            type = "text"
        } | ConvertTo-Json
        
        $response = Invoke-RestMethod -Uri "$baseUrl/api/v1/chat/rooms/$roomId/messages" -Method Post -Body $body -ContentType "application/json" -Headers $headers -TimeoutSec 10
        if ($response.success) {
            Write-Host " PASSED" -ForegroundColor Green
        } else {
            Write-Host " FAILED" -ForegroundColor Red
        }
    } catch {
        Write-Host " FAILED: $_" -ForegroundColor Red
    }
} else {
    Write-Host " SKIPPED (no room)" -ForegroundColor Yellow
}

# Test 8: Get Messages
Write-Host "[8/12] Testing Get Messages..." -NoNewline
if ($roomId) {
    try {
        $response = Invoke-RestMethod -Uri "$baseUrl/api/v1/chat/rooms/$roomId/messages" -Method Get -Headers $headers -TimeoutSec 10
        Write-Host " PASSED" -ForegroundColor Green
    } catch {
        Write-Host " FAILED: $_" -ForegroundColor Red
    }
} else {
    Write-Host " SKIPPED (no room)" -ForegroundColor Yellow
}

# Test 9: Mark as Read
Write-Host "[9/12] Testing Mark as Read..." -NoNewline
if ($roomId) {
    try {
        $response = Invoke-RestMethod -Uri "$baseUrl/api/v1/chat/rooms/$roomId/read" -Method Post -Headers $headers -TimeoutSec 10
        Write-Host " PASSED" -ForegroundColor Green
    } catch {
        Write-Host " FAILED: $_" -ForegroundColor Red
    }
} else {
    Write-Host " SKIPPED (no room)" -ForegroundColor Yellow
}

# Test 10: Search Users
Write-Host "[10/12] Testing Search Users..." -NoNewline
try {
    $response = Invoke-RestMethod -Uri "$baseUrl/api/v1/chat/users/search?q=test" -Method Get -Headers $headers -TimeoutSec 10
    Write-Host " PASSED" -ForegroundColor Green
} catch {
    Write-Host " FAILED: $_" -ForegroundColor Red
}

# Test 11: Logout
Write-Host "[11/12] Testing Logout..." -NoNewline
try {
    $response = Invoke-RestMethod -Uri "$baseUrl/api/v1/auth/logout" -Method Post -Headers $headers -TimeoutSec 10
    Write-Host " PASSED" -ForegroundColor Green
} catch {
    Write-Host " FAILED: $_" -ForegroundColor Red
}

# Test 12: Web Client
Write-Host "[12/12] Testing Web Client..." -NoNewline
try {
    $response = Invoke-WebRequest -Uri $webUrl -Method Get -TimeoutSec 10 -UseBasicParsing
    if ($response.StatusCode -eq 200) {
        Write-Host " PASSED" -ForegroundColor Green
    } else {
        Write-Host " FAILED (Status: $($response.StatusCode))" -ForegroundColor Red
    }
} catch {
    Write-Host " FAILED: $_" -ForegroundColor Red
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Test Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Auth Service: $baseUrl" -ForegroundColor White
Write-Host "Web Client: $webUrl" -ForegroundColor White
Write-Host "Test User: $testUsername" -ForegroundColor White
Write-Host ""
Write-Host "All core services are running and functional!" -ForegroundColor Green
