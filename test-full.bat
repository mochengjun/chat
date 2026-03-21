@echo off
setlocal enabledelayedexpansion

echo === Full API Functional Tests ===
echo.

echo [Test 1] Health Check...
curl -s http://localhost:8081/health
echo.
echo.

echo [Test 2] User Registration...
curl -s -X POST http://localhost:8081/api/v1/auth/register -H "Content-Type: application/json" -d "{\"username\":\"fulltest123\",\"password\":\"Test123456\",\"email\":\"fulltest@test.com\"}"
echo.
echo.

echo [Test 3] User Login...
for /f "delims=" %%i in ('curl -s -X POST http://localhost:8081/api/v1/auth/login -H "Content-Type: application/json" -d "{\"username\":\"fulltest123\",\"password\":\"Test123456\"}"') do set LOGIN_RESPONSE=%%i
echo !LOGIN_RESPONSE!
echo.

:: Extract token (simple approach - get the access_token value)
for /f "tokens=2 delims=:" %%a in ('echo !LOGIN_RESPONSE! ^| findstr /r "access_token"') do (
    set TOKEN_PART=%%a
)
:: Clean up token (remove quotes and comma)
set TOKEN=!TOKEN_PART:"=!
set TOKEN=!TOKEN:,=!
set TOKEN=!TOKEN: =!

echo.
echo [Test 4] Get Chat Rooms (with auth)...
curl -s http://localhost:8081/api/v1/chat/rooms -H "Authorization: Bearer !TOKEN!"
echo.
echo.

echo [Test 5] Create Chat Room...
for /f "delims=" %%i in ('curl -s -X POST http://localhost:8081/api/v1/chat/rooms -H "Content-Type: application/json" -H "Authorization: Bearer !TOKEN!" -d "{\"name\":\"Test Room\",\"topic\":\"Test room topic\"}"') do set ROOM_RESPONSE=%%i
echo !ROOM_RESPONSE!
echo.

echo [Test 6] Web Client Check...
curl -s -o nul -w "HTTP Status: %%{http_code}" http://localhost:3000/
echo.
echo.

echo === All Tests Completed ===
