@echo off
REM ============================================================
REM Android 模拟器启动脚本
REM ============================================================

echo.
echo ============================================================
echo    Android 模拟器启动程序
echo ============================================================
echo.

REM 设置 Android SDK 路径
set "ANDROID_SDK=C:\Android\Sdk"

echo [信息] 检查已运行的模拟器进程...
tasklist | findstr emulator.exe >nul 2>&1
if %errorlevel% equ 0 (
    echo [警告] 检测到模拟器已在运行，正在关闭...
    taskkill /F /IM emulator.exe /T >nul 2>&1
    timeout /t 3 /nobreak >nul
)

echo [信息] 关闭 qemu 系统进程...
for /f "tokens=2" %%i in ('tasklist ^| findstr qemu-system') do (
    echo [信息] 停止进程 ID: %%i
    taskkill /F /PID %%i >nul 2>&1
)

echo [信息] 重启 ADB 服务器...
"%ANDROID_SDK%\platform-tools\adb.exe" kill-server
timeout /t 2 /nobreak >nul
"%ANDROID_SDK%\platform-tools\adb.exe" start-server

echo.
echo [信息] 可用的模拟器列表:
"%ANDROID_SDK%\emulator\emulator.exe" -list-avds

echo.
echo [信息] 启动 Pixel_6_API_34 模拟器...
echo [提示] 模拟器启动需要 1-2 分钟，请耐心等待...
echo.

start "" "%ANDROID_SDK%\emulator\emulator.exe" -avd Pixel_6_API_34 -no-boot-anim

echo [信息] 模拟器已启动，正在等待设备连接...
timeout /t 10 /nobreak >nul

:wait_for_device
"%ANDROID_SDK%\platform-tools\adb.exe" devices | findstr device >nul 2>&1
if %errorlevel% neq 0 (
    echo [等待] 设备启动中...
    timeout /t 5 /nobreak >nul
    goto :wait_for_device
)

echo.
echo [成功] 设备已连接!
"%ANDROID_SDK%\platform-tools\adb.exe" devices

echo.
echo [信息] 获取设备信息...
"%ANDROID_SDK%\platform-tools\adb.exe" shell getprop ro.build.version.release
"%ANDROID_SDK%\platform-tools\adb.exe" shell getprop ro.product.model

echo.
echo ============================================================
echo    模拟器启动完成!
echo ============================================================
echo.

pause
