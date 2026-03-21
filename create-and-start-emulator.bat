@echo off
REM ============================================================
REM 创建并启动Android模拟器
REM ============================================================

echo.
echo ============================================================
echo    创建并启动Android模拟器
echo ============================================================
echo.

set "ANDROID_SDK=C:\Android\Sdk"
set "AVD_NAME=Pixel_6_API_34"
set "IMAGE_TAG=google_apis"

REM 检查模拟器是否已存在
echo [步骤 1/3] 检查现有模拟器...
%ANDROID_SDK%\emulator\emulator.exe -list-avds | findstr "%AVD_NAME%" >nul 2>&1
if %errorlevel% equ 0 (
    echo    [OK] 模拟器 %AVD_NAME% 已存在
    goto :start_emulator
)

echo.
echo [步骤 2/3] 创建新的Android虚拟设备...
echo    设备名称: %AVD_NAME%
echo    系统镜像: android-34 (%IMAGE_TAG%)
echo.

REM 创建AVD配置目录
if not exist "%USERPROFILE%\.android\avd" mkdir "%USERPROFILE%\.android\avd"

REM 创建AVD配置文件
echo type=device > "%USERPROFILE%\.android\avd\%AVD_NAME%.avd\config.ini"
echo PlayStore.enabled=false >> "%USERPROFILE%\.android\avd\%AVD_NAME%.avd\config.ini"
echo abi.type=x86_64 >> "%USERPROFILE%\.android\avd\%AVD_NAME%.avd\config.ini"
echo avd.ini.encoding=UTF-8 >> "%USERPROFILE%\.android\avd\%AVD_NAME%.avd\config.ini"
echo hw.accelerometer=yes >> "%USERPROFILE%\.android\avd\%AVD_NAME%.avd\config.ini"
echo hw.audioInput=yes >> "%USERPROFILE%\.android\avd\%AVD_NAME%.avd\config.ini"
echo hw.battery=yes >> "%USERPROFILE%\.android\avd\%AVD_NAME%.avd\config.ini"
echo hw.camera.back=emulated >> "%USERPROFILE%\.android\avd\%AVD_NAME%.avd\config.ini"
echo hw.camera.front=emulated >> "%USERPROFILE%\.android\avd\%AVD_NAME%.avd\config.ini"
echo hw.cpu.arch=x86_64 >> "%USERPROFILE%\.android\avd\%AVD_NAME%.avd\config.ini"
echo hw.device.hash2=MD5:bc5032b2a871f5f33b15b0fcfcb3f8f9 >> "%USERPROFILE%\.android\avd\%AVD_NAME%.avd\config.ini"
echo hw.device.manufacturer=Google >> "%USERPROFILE%\.android\avd\%AVD_NAME%.avd\config.ini"
echo hw.device.name=pixel_6 >> "%USERPROFILE%\.android\avd\%AVD_NAME%.avd\config.ini"
echo hw.gps=yes >> "%USERPROFILE%\.android\avd\%AVD_NAME%.avd\config.ini"
echo hw.gpu.enabled=yes >> "%USERPROFILE%\.android\avd\%AVD_NAME%.avd\config.ini"
echo hw.gpu.mode=host >> "%USERPROFILE%\.android\avd\%AVD_NAME%.avd\config.ini"
echo hw.keyboard=yes >> "%USERPROFILE%\.android\avd\%AVD_NAME%.avd\config.ini"
echo hw.lcd.density=420 >> "%USERPROFILE%\.android\avd\%AVD_NAME%.avd\config.ini"
echo hw.lcd.height=2400 >> "%USERPROFILE%\.android\avd\%AVD_NAME%.avd\config.ini"
echo hw.lcd.width=1080 >> "%USERPROFILE%\.android\avd\%AVD_NAME%.avd\config.ini"
echo hw.ramSize=4096 >> "%USERPROFILE%\.android\avd\%AVD_NAME%.avd\config.ini"
echo hw.sensors.orientation=yes >> "%USERPROFILE%\.android\avd\%AVD_NAME%.avd\config.ini"
echo hw.sensors.proximity=yes >> "%USERPROFILE%\.android\avd\%AVD_NAME%.avd\config.ini"
echo image.sysdir.1=system-images\android-34\%IMAGE_TAG%\x86_64\ >> "%USERPROFILE%\.android\avd\%AVD_NAME%.avd\config.ini"
echo tag.display=Google APIs >> "%USERPROFILE%\.android\avd\%AVD_NAME%.avd\config.ini"
echo tag.id=%IMAGE_TAG% >> "%USERPROFILE%\.android\avd\%AVD_NAME%.avd\config.ini"

REM 创建AVD ini文件
echo avd.ini.encoding=UTF-8 > "%USERPROFILE%\.android\avd\%AVD_NAME%.ini"
echo path=%USERPROFILE%\.android\avd\%AVD_NAME%.avd >> "%USERPROFILE%\.android\avd\%AVD_NAME%.ini"
echo path.rel=avd\%AVD_NAME%.avd >> "%USERPROFILE%\.android\avd\%AVD_NAME%.ini"
echo target=android-34 >> "%USERPROFILE%\.android\avd\%AVD_NAME%.ini"

REM 创建AVD目录
if not exist "%USERPROFILE%\.android\avd\%AVD_NAME%.avd" mkdir "%USERPROFILE%\.android\avd\%AVD_NAME%.avd"

echo    [OK] AVD配置文件已创建

:start_emulator
echo.
echo [步骤 3/3] 启动模拟器...
echo    这可能需要 1-2 分钟...
echo.

REM 关闭现有模拟器
tasklist | findstr emulator.exe >nul 2>&1
if %errorlevel% equ 0 (
    echo    [信息] 关闭现有模拟器进程...
    taskkill /F /IM emulator.exe /T >nul 2>&1
    timeout /t 3 /nobreak >nul
)

REM 重启ADB服务
%ANDROID_SDK%\platform-tools\adb.exe kill-server >nul 2>&1
timeout /t 2 /nobreak >nul
%ANDROID_SDK%\platform-tools\adb.exe start-server >nul 2>&1

REM 启动模拟器（后台运行）
start "Android Emulator" /MIN "%ANDROID_SDK%\emulator\emulator.exe" -avd %AVD_NAME% -no-boot-anim -no-audio -gpu host

echo    [信息] 模拟器正在启动...
echo    [提示] 请等待模拟器完全启动（约1-2分钟）
echo.

REM 等待设备连接
set /a WAIT_COUNT=0
:wait_device
%ANDROID_SDK%\platform-tools\adb.exe devices | findstr "device$" >nul 2>&1
if %errorlevel% equ 0 (
    echo.
    echo    [成功] 设备已连接！
    %ANDROID_SDK%\platform-tools\adb.exe devices
    echo.
    echo    设备信息:
    %ANDROID_SDK%\platform-tools\adb.exe shell getprop ro.build.version.release
    %ANDROID_SDK%\platform-tools\adb.exe shell getprop ro.product.model
    echo.
    echo ============================================================
    echo    模拟器启动成功！
    echo ============================================================
    echo.
    goto :end
)

set /a WAIT_COUNT+=1
if %WAIT_COUNT% geq 30 (
    echo.
    echo    [错误] 等待超时，设备未能在30秒内连接
    echo    请检查模拟器窗口是否出现
    echo.
    goto :end
)

echo    等待设备连接... (%WAIT_COUNT%/30)
timeout /t 1 /nobreak >nul
goto :wait_device

:end
pause
