@echo off
REM ============================================================
REM 服务连通性快速测试 (批处理版本)
REM 服务器IP: 8.130.55.126
REM 可在任何Windows电脑上运行测试到服务器的连通性
REM ============================================================

set SERVER=8.130.55.126

echo ==========================================
echo 服务连通性快速测试
echo 服务器IP: %SERVER%
echo 测试时间: %date% %time%
echo ==========================================
echo.

echo === 端口连通性测试 ===
echo.

echo 测试SSH端口22...
powershell -Command "try{$t=New-Object Net.Sockets.TcpClient;$t.Connect('%SERVER%',22);Write-Host '  [通过] 端口22可访问' -ForegroundColor Green}catch{Write-Host '  [失败] 端口22不可访问' -ForegroundColor Red}"

echo 测试HTTP端口80...
powershell -Command "try{$t=New-Object Net.Sockets.TcpClient;$t.Connect('%SERVER%',80);Write-Host '  [通过] 端口80可访问' -ForegroundColor Green}catch{Write-Host '  [失败] 端口80不可访问' -ForegroundColor Red}"

echo 测试HTTPS端口443...
powershell -Command "try{$t=New-Object Net.Sockets.TcpClient;$t.Connect('%SERVER%',443);Write-Host '  [通过] 端口443可访问' -ForegroundColor Green}catch{Write-Host '  [失败] 端口443不可访问' -ForegroundColor Red}"

echo 测试API端口8081...
powershell -Command "try{$t=New-Object Net.Sockets.TcpClient;$t.Connect('%SERVER%',8081);Write-Host '  [通过] 端口8081可访问' -ForegroundColor Green}catch{Write-Host '  [失败] 端口8081不可访问' -ForegroundColor Red}"

echo.
echo === HTTP服务测试 ===
echo.

echo 测试API健康检查 (端口80)...
curl -s -o nul -w "  HTTP状态码: %%{http_code}\n" http://%SERVER%/health 2>nul || echo   [失败] 无法访问

echo 测试API健康检查 (端口8081)...
curl -s -o nul -w "  HTTP状态码: %%{http_code}\n" http://%SERVER%:8081/health 2>nul || echo   [失败] 无法访问

echo.
echo ==========================================
echo 测试完成
echo ==========================================
echo.
echo 如果所有端口测试失败:
echo   1. 检查阿里云安全组是否开放端口
echo   2. 检查服务器防火墙配置
echo   3. 确认服务器上的服务已启动
echo.
echo 如果端口通但HTTP返回错误:
echo   1. 检查Docker容器状态: docker ps
echo   2. 查看服务日志: docker compose logs
echo.
pause
