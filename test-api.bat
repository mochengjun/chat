@echo off
echo === API Functional Tests ===
echo.

echo [Test 1] Health Check...
curl -s http://localhost:8081/health
echo.
echo.

echo [Test 2] User Registration...
curl -s -X POST http://localhost:8081/api/v1/auth/register -H "Content-Type: application/json" -d "{\"username\":\"bathtest123\",\"password\":\"Test123456\",\"email\":\"bathtest@test.com\"}"
echo.
echo.

echo [Test 3] User Login...
curl -s -X POST http://localhost:8081/api/v1/auth/login -H "Content-Type: application/json" -d "{\"username\":\"bathtest123\",\"password\":\"Test123456\"}"
echo.
echo.

echo === All Tests Completed ===
