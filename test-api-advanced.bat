@echo off
echo === Advanced API Tests ===
echo.

:: Step 1: Login and save token
echo [Step 1] Login and get token...
curl -s -X POST http://localhost:8081/api/v1/auth/login -H "Content-Type: application/json" -d "{\"username\":\"fulltest123\",\"password\":\"Test123456\"}" > %TEMP%\login_response.json
type %TEMP%\login_response.json
echo.
echo.

:: Step 2: Use hardcoded token from above for testing
echo [Step 2] Test with token...
echo Note: Token extraction in batch is complex, testing with manual token
echo.

:: Get a fresh token using PowerShell
powershell -NoProfile -Command "$r = Invoke-RestMethod -Uri 'http://localhost:8081/api/v1/auth/login' -Method POST -Body (Get-Content -Raw 'c:/Users/HZHF/source/chat/login_req.json') -ContentType 'application/json'; $r.access_token" > %TEMP%\token.txt
set /p TOKEN=<%TEMP%\token.txt
echo Token obtained: %TOKEN:~0,50%...
echo.

echo [Test 4] Get Chat Rooms...
curl -s http://localhost:8081/api/v1/chat/rooms -H "Authorization: Bearer %TOKEN%"
echo.
echo.

echo [Test 5] Create Chat Room...
curl -s -X POST http://localhost:8081/api/v1/chat/rooms -H "Content-Type: application/json" -H "Authorization: Bearer %TOKEN%" -d "{\"name\":\"API Test Room\",\"topic\":\"Created via API test\"}"
echo.
echo.

echo [Test 6] Get Current User...
curl -s http://localhost:8081/api/v1/auth/me -H "Authorization: Bearer %TOKEN%"
echo.
echo.

echo [Test 7] Search Users...
curl -s "http://localhost:8081/api/v1/chat/users/search?search=test" -H "Authorization: Bearer %TOKEN%"
echo.
echo.

echo === All Tests Completed ===
