# API测试脚本
$baseUrl = "http://localhost:8081/api/v1"

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "   Auth Service API Test" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

# 1. Health Check
Write-Host "[1] Health Check..." -ForegroundColor Yellow
try {
    $health = Invoke-RestMethod -Uri "http://localhost:8081/health" -Method Get
    Write-Host "  Status: $($health.status)" -ForegroundColor Green
    Write-Host "  DB Type: $($health.db_type)" -ForegroundColor Green
    Write-Host "  Service: $($health.service)" -ForegroundColor Green
} catch {
    Write-Host "  Error: $_" -ForegroundColor Red
}

Write-Host ""

# Generate unique username with random number
$random = Get-Random -Maximum 999999
$username = "user_$random"
$email = "user_$random@test.com"

# 2. Register User
Write-Host "[2] Register User ($username)..." -ForegroundColor Yellow
$registerBody = @{
    username = $username
    password = "Test123456"
    email = $email
    displayName = "Test User $random"
} | ConvertTo-Json

Write-Host "  Request body: $registerBody" -ForegroundColor Gray

try {
    $registerResult = Invoke-RestMethod -Uri "$baseUrl/auth/register" -Method Post -Body $registerBody -ContentType "application/json"
    Write-Host "  Registration successful!" -ForegroundColor Green
    Write-Host "  User ID: $($registerResult.user_id)" -ForegroundColor Green
    Write-Host "  Username: $($registerResult.username)" -ForegroundColor Green
    
    # Now login to get token
    Write-Host ""
    Write-Host "[2b] Login to get token..." -ForegroundColor Yellow
    $loginBody = @{
        username = $username
        password = "Test123456"
    } | ConvertTo-Json
    
    $loginResult = Invoke-RestMethod -Uri "$baseUrl/auth/login" -Method Post -Body $loginBody -ContentType "application/json"
    Write-Host "  Login successful!" -ForegroundColor Green
    $accessToken = $loginResult.access_token
    $refreshToken = $loginResult.refresh_token
    Write-Host "  Access Token: $($accessToken.Substring(0, [Math]::Min(20, $accessToken.Length)))..." -ForegroundColor Green
} catch {
    $errorResponse = $_.ErrorDetails.Message
    Write-Host "  Error: $errorResponse" -ForegroundColor Red
}

Write-Host ""

# 3. Get User Info
if ($accessToken) {
    Write-Host "[3] Get Current User..." -ForegroundColor Yellow
    $headers = @{
        Authorization = "Bearer $accessToken"
    }
    try {
        $userResult = Invoke-RestMethod -Uri "$baseUrl/users/me" -Method Get -Headers $headers
        Write-Host "  User ID: $($userResult.id)" -ForegroundColor Green
        Write-Host "  Username: $($userResult.username)" -ForegroundColor Green
        Write-Host "  Email: $($userResult.email)" -ForegroundColor Green
    } catch {
        Write-Host "  Error: $($_.ErrorDetails.Message)" -ForegroundColor Red
    }
}

Write-Host ""

# 4. Get Public Rooms
if ($accessToken) {
    Write-Host "[4] Get Public Rooms..." -ForegroundColor Yellow
    try {
        $rooms = Invoke-RestMethod -Uri "$baseUrl/chat/rooms/public" -Method Get -Headers $headers
        Write-Host "  Found $($rooms.Count) public rooms" -ForegroundColor Green
        foreach ($room in $rooms) {
            Write-Host "    - $($room.name) ($($room.id))" -ForegroundColor Gray
        }
    } catch {
        Write-Host "  Error: $($_.ErrorDetails.Message)" -ForegroundColor Red
    }
} else {
    Write-Host "[4] Get Public Rooms... SKIPPED (no token)" -ForegroundColor Yellow
}

Write-Host ""

# 5. Create Room
if ($accessToken) {
    Write-Host "[5] Create Test Room..." -ForegroundColor Yellow
    $roomBody = @{
        name = "Test Room $random"
        type = "group"
    } | ConvertTo-Json
    
    try {
        $roomResult = Invoke-RestMethod -Uri "$baseUrl/chat/rooms" -Method Post -Body $roomBody -ContentType "application/json" -Headers $headers
        Write-Host "  Room created: $($roomResult.id)" -ForegroundColor Green
        Write-Host "  Room name: $($roomResult.name)" -ForegroundColor Green
        $roomId = $roomResult.id
    } catch {
        Write-Host "  Error: $($_.ErrorDetails.Message)" -ForegroundColor Red
    }
}

Write-Host ""

# 6. Get My Rooms
if ($accessToken) {
    Write-Host "[6] Get My Rooms..." -ForegroundColor Yellow
    try {
        $myRooms = Invoke-RestMethod -Uri "$baseUrl/chat/rooms" -Method Get -Headers $headers
        Write-Host "  Found $($myRooms.Count) rooms" -ForegroundColor Green
        foreach ($room in $myRooms) {
            Write-Host "    - $($room.name) ($($room.id))" -ForegroundColor Gray
        }
    } catch {
        Write-Host "  Error: $($_.ErrorDetails.Message)" -ForegroundColor Red
    }
}

Write-Host ""

# 7. Send Message
if ($accessToken -and $roomId) {
    Write-Host "[7] Send Message..." -ForegroundColor Yellow
    $msgBody = @{
        content = "Hello, this is a test message!"
        type = "text"
    } | ConvertTo-Json
    
    try {
        $msgResult = Invoke-RestMethod -Uri "$baseUrl/chat/rooms/$roomId/messages" -Method Post -Body $msgBody -ContentType "application/json" -Headers $headers
        Write-Host "  Message sent: $($msgResult.id)" -ForegroundColor Green
    } catch {
        Write-Host "  Error: $($_.ErrorDetails.Message)" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "   API Test Completed" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
