@echo off
echo === Message and Full Feature Tests ===
echo.

:: Get token
powershell -NoProfile -Command "$r = Invoke-RestMethod -Uri 'http://localhost:8081/api/v1/auth/login' -Method POST -Body '{\"username\":\"fulltest123\",\"password\":\"Test123456\"}' -ContentType 'application/json'; $r.access_token" > %TEMP%\token.txt
set /p TOKEN=<%TEMP%\token.txt
echo Token obtained.
echo.

:: Create a room first
echo [Test 1] Create Room...
curl -s -X POST http://localhost:8081/api/v1/chat/rooms -H "Content-Type: application/json" -H "Authorization: Bearer %TOKEN%" -d "{\"name\":\"Message Test Room\",\"topic\":\"For testing messages\"}" > %TEMP%\room.json
type %TEMP%\room.json
echo.
echo.

:: Extract room ID using PowerShell
powershell -NoProfile -Command "$r = Get-Content '%TEMP%\room.json' | ConvertFrom-Json; $r.id" > %TEMP%\room_id.txt
set /p ROOM_ID=<%TEMP%\room_id.txt
echo Room ID: %ROOM_ID%
echo.

:: Send a message
echo [Test 2] Send Message...
curl -s -X POST "http://localhost:8081/api/v1/chat/rooms/%ROOM_ID%/messages" -H "Content-Type: application/json" -H "Authorization: Bearer %TOKEN%" -d "{\"content\":\"Hello from automated test!\"}"
echo.
echo.

:: Get messages
echo [Test 3] Get Messages...
curl -s "http://localhost:8081/api/v1/chat/rooms/%ROOM_ID%/messages" -H "Authorization: Bearer %TOKEN%"
echo.
echo.

:: Mark as read
echo [Test 4] Mark as Read...
curl -s -X POST "http://localhost:8081/api/v1/chat/rooms/%ROOM_ID%/read" -H "Authorization: Bearer %TOKEN%"
echo.
echo.

:: Get rooms again
echo [Test 5] Get Rooms (should show new room)...
curl -s http://localhost:8081/api/v1/chat/rooms -H "Authorization: Bearer %TOKEN%"
echo.
echo.

:: Test refresh token
echo [Test 6] Refresh Token...
curl -s -X POST http://localhost:8081/api/v1/auth/refresh -H "Content-Type: application/json" -d "{\"refresh_token\":\"any\"}" 2>nul || echo "Refresh token test (expected to fail with invalid token)"
echo.
echo.

:: Test logout
echo [Test 7] Logout...
curl -s -X POST http://localhost:8081/api/v1/auth/logout -H "Authorization: Bearer %TOKEN%"
echo.
echo.

echo === All Message Tests Completed ===
