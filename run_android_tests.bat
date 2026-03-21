@echo off
REM ============================================================
REM Android应用测试执行脚本
REM ============================================================

echo.
echo ============================================================
echo    SecChat Android应用测试
echo ============================================================
echo.

REM 检查Python
python --version >nul 2>&1
if %errorlevel% neq 0 (
    echo [错误] Python未安装或未添加到PATH
    echo        请安装Python 3.7+
    pause
    exit /b 1
)

echo [信息] Python环境检查通过
echo.

REM 检查ADB
set "ADB=C:\Android\Sdk\platform-tools\adb.exe"
if not exist "%ADB%" (
    echo [错误] ADB未找到: %ADB%
    echo        请确保Android SDK已正确安装
    pause
    exit /b 1
)

echo [信息] ADB工具检查通过
echo.

REM 检查设备
echo [步骤 1/4] 检查设备连接...
"%ADB%" devices
echo.

REM 检查APK
echo [步骤 2/4] 检查APK文件...
if not exist "installer\android\SecChat-debug.apk" (
    echo [错误] APK文件不存在
    echo        请先构建APK: build-android.bat
    pause
    exit /b 1
)
echo [信息] APK文件检查通过
echo.

REM 执行测试
echo [步骤 3/4] 执行自动化测试...
echo.
python test_android_app.py

echo.
echo [步骤 4/4] 测试完成！
echo.
echo 查看测试结果:
echo   - 测试日志: test_results.log
echo   - 测试报告: test_report_*.json
echo   - Markdown报告: test_report_*.md
echo   - 截图: screenshots\
echo   - 日志: logs\
echo.

pause
