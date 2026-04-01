@echo off
REM ============================================================
REM 阿里云服务器端口连通性测试 (Windows版本)
REM 服务器IP: 8.130.55.126
REM ============================================================

echo ==========================================
echo 阿里云服务器端口连通性测试
echo 服务器IP: 8.130.55.126
echo ==========================================
echo.

REM 测试端口函数
:test_port
set PORT=%~1
set NAME=%~2
echo 测试 %NAME% 端口 %PORT%...
powershell -Command "$t = New-Object Net.Sockets.TcpClient; try { $t.Connect('8.130.55.126', %PORT%); Write-Host '  [PASS] 端口 %PORT% 可访问' -ForegroundColor Green; exit 0 } catch { Write-Host '  [FAIL] 端口 %PORT% 不可访问' -ForegroundColor Red; exit 1 }"
goto :eof

echo === 端口连通性测试 ===
echo.

call :test_port 22 "SSH"
call :test_port 80 "HTTP"
call :test_port 443 "HTTPS"
call :test_port 8081 "API"

echo.
echo ==========================================
echo HTTP服务测试
echo ==========================================
echo.

echo 测试 API 健康检查 (通过端口 80)...
curl -s -o nul -w "  HTTP状态码: %%{http_code}\n" http://8.130.55.126/health 2>nul || echo   [FAIL] 无法访问

echo 测试 API 健康检查 (通过端口 8081)...
curl -s -o nul -w "  HTTP状态码: %%{http_code}\n" http://8.130.55.126:8081/health 2>nul || echo   [FAIL] 无法访问

echo.
echo ==========================================
echo 测试完成
echo ==========================================
echo.
echo 如果端口不可访问，请检查:
echo 1. 阿里云安全组是否开放了相应端口
echo 2. 服务器防火墙是否开放了相应端口
echo 3. 服务是否已启动
echo.
pause
