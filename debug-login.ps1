# Debug Login Response
$baseUrl = "http://localhost:8081"

Write-Host "=== Debug Login Response ===" -ForegroundColor Cyan

# Register a new user
$timestamp = Get-Date -Format "yyyyMMddHHmmss"
$registerBody = @{
    username = "debuguser_$timestamp"
    password = "Test123456"
    email = "debug$timestamp@test.com"
} | ConvertTo-Json

Write-Host "`nRegistering user..." -ForegroundColor Yellow
$regResponse = Invoke-RestMethod -Uri "$baseUrl/api/v1/auth/register" -Method POST -Body $registerBody -ContentType "application/json"
Write-Host "Register Response:" -ForegroundColor Green
$regResponse | ConvertTo-Json -Depth 5

# Login
$loginBody = @{
    username = "debuguser_$timestamp"
    password = "Test123456"
} | ConvertTo-Json

Write-Host "`nLogging in..." -ForegroundColor Yellow
$loginResponse = Invoke-RestMethod -Uri "$baseUrl/api/v1/auth/login" -Method POST -Body $loginBody -ContentType "application/json"
Write-Host "Login Response:" -ForegroundColor Green
$loginResponse | ConvertTo-Json -Depth 5

Write-Host "`nToken value:" -ForegroundColor Yellow
Write-Host $loginResponse.data.token

Write-Host "`nTesting with token..." -ForegroundColor Yellow
$token = $loginResponse.data.token
$headers = @{ Authorization = "Bearer $token" }
Write-Host "Headers:"
$headers | ConvertTo-Json

$roomsResponse = Invoke-RestMethod -Uri "$baseUrl/api/v1/chat/rooms" -Method GET -Headers $headers
Write-Host "Rooms Response:" -ForegroundColor Green
$roomsResponse | ConvertTo-Json -Depth 5
