@echo off
REM ============================================================
REM Android测试问题自动修复脚本
REM 修复应用启动失败和网络连接失败问题
REM ============================================================

echo.
echo ============================================================
echo    Android测试问题自动修复
echo ============================================================
echo.

set "ANDROID_SDK=C:\Android\Sdk"
set "ADB=%ANDROID_SDK%\platform-tools\adb.exe"
set "PACKAGE=com.example.sec_chat"
set "APK=installer\android\SecChat-debug.apk"

REM 检查ADB
echo [步骤 1/6] 检查ADB工具...
if not exist "%ADB%" (
    echo [错误] ADB未找到: %ADB%
    echo        请确保Android SDK已正确安装
    pause
    exit /b 1
)
echo [OK] ADB工具可用

REM 检查设备
echo.
echo [步骤 2/6] 检查设备连接...
%ADB% devices | findstr "device$" >nul
if errorlevel 1 (
    echo [错误] 未检测到设备，请先启动模拟器
    echo.
    echo 启动模拟器的方法:
    echo   1. 运行: create-and-start-emulator.bat
    echo   2. 或手动启动: %ANDROID_SDK%\emulator\emulator.exe -avd Pixel_6_API_34
    echo.
    pause
    exit /b 1
)
echo [OK] 设备已连接
%ADB% devices
echo.

REM 等待设备完全启动
echo [步骤 3/6] 等待设备完全启动...
set /a WAIT_COUNT=0
:wait_boot
%ADB% shell getprop sys.boot_completed 2>nul | findstr "1" >nul
if not errorlevel 1 goto boot_complete
set /a WAIT_COUNT+=1
if %WAIT_COUNT% geq 30 (
    echo [错误] 等待设备启动超时
    echo        请检查模拟器是否卡死
    pause
    exit /b 1
)
echo   等待设备启动... (%WAIT_COUNT%/30)
timeout /t 2 /nobreak >nul
goto wait_boot
:boot_complete
echo [OK] 设备已完全启动
echo.

REM 修复网络连接
echo [步骤 4/6] 修复网络连接...
echo   配置DNS服务器...
%ADB% shell setprop net.dns1 114.114.114.114 2>nul
%ADB% shell setprop net.dns2 223.5.5.5 2>nul

REM 测试网络连接
echo   测试网络连接...
%ADB% shell ping -c 1 10.0.2.2 >nul 2>&1
if not errorlevel 1 (
    echo [OK] 本地网络连接正常
) else (
    echo [警告] 本地网络连接测试失败，尝试切换飞行模式...
    %ADB% shell settings put global airplane_mode_on 1 2>nul
    %ADB% shell am broadcast -a android.intent.action.AIRPLANE_MODE 2>nul
    timeout /t 2 /nobreak >nul
    %ADB% shell settings put global airplane_mode_on 0 2>nul
    %ADB% shell am broadcast -a android.intent.action.AIRPLANE_MODE 2>nul
    timeout /t 2 /nobreak >nul
    echo [OK] 已重置网络连接
)
echo.

REM 重新安装应用
echo [步骤 5/6] 重新安装应用...
%ADB% shell pm list packages 2>nul | findstr "%PACKAGE%" >nul
if not errorlevel 1 (
    echo   卸载旧版本...
    %ADB% uninstall %PACKAGE% >nul 2>&1
    if not errorlevel 1 (
        echo [OK] 旧版本已卸载
    )
)

if not exist "%APK%" (
    echo [错误] APK文件不存在: %APK%
    echo        请先构建APK
    pause
    exit /b 1
)

echo   安装新版本...
%ADB% install -r "%APK%" >nul 2>&1
if errorlevel 1 (
    echo [错误] 安装失败，尝试使用-g参数...
    %ADB% install -r -g "%APK%"
    if errorlevel 1 (
        echo [错误] 安装仍然失败
        pause
        exit /b 1
    )
)
echo [OK] 应用安装成功

REM 验证修复
echo.
echo [步骤 6/6] 验证修复结果...

REM 检查应用是否已安装
%ADB% shell pm list packages 2>nul | findstr "%PACKAGE%" >nul
if errorlevel 1 (
    echo [错误] 应用未正确安装
    pause
    exit /b 1
)
echo   [OK] 应用已安装

REM 启动应用
echo   启动应用...
%ADB% shell am start -n %PACKAGE%/.MainActivity >nul 2>&1
timeout /t 3 /nobreak >nul

REM 检查应用状态
echo   检查应用状态...
%ADB% shell dumpsys activity activities 2>nul | findstr mResumedActivity | findstr "%PACKAGE%" >nul
if not errorlevel 1 (
    echo   [OK] 应用已成功启动并运行在前台
) else (
    echo   [警告] 应用可能未在前台运行，尝试查找正确的Activity...
    %ADB% shell dumpsys package %PACKAGE% 2>nul | findstr "Activity" | head -5
)

REM 测试网络连接
echo   测试网络连接...
%ADB% shell ping -c 1 10.0.2.2 >nul 2>&1
if not errorlevel 1 (
    echo   [OK] 网络连接正常
) else (
    echo   [警告] 网络连接可能有问题，但应用仍可测试
)

REM 截屏保存
echo   保存截图...
%ADB% shell screencap -p /sdcard/fix_verify.png 2>nul
%ADB% pull /sdcard/fix_verify.png screenshots\fix_verify.png >nul 2>&1
echo   [OK] 截图已保存: screenshots\fix_verify.png

echo.
echo ============================================================
echo    修复完成！
echo ============================================================
echo.
echo 现在可以重新运行测试:
echo   python test_android_app.py
echo.
echo 或运行批处理测试:
echo   run_android_tests.bat
echo.

pause
