@echo off
chcp 65001 >nul
REM ============================================================
REM Flutter Android应用完整UI功能测试
REM 基于ANDROID_EMULATOR_TEST_PLAN.md执行全面测试
REM ============================================================

setlocal EnableDelayedExpansion

REM 强制设置 JAVA_HOME 为 JDK 17
set "JAVA_HOME=C:\Program Files\Eclipse Adoptium\jdk-17.0.18.8-hotspot"
set "PATH=%JAVA_HOME%\bin;%PATH%"

set "ADB=C:\Android\Sdk\platform-tools\adb.exe"
set "APK=installer\android\SecChat-debug.apk"
set "PACKAGE=com.example.sec_chat"
set "REPORT_DIR=test-results\ui_test"
set "SCREENSHOT_DIR=screenshots\ui_test"

echo.
echo ============================================================
echo    Flutter Android应用完整UI功能测试
echo    测试日期: %date% %time%
echo ============================================================
echo.

REM 创建报告目录
if not exist "%REPORT_DIR%" mkdir "%REPORT_DIR%"
if not exist "%SCREENSHOT_DIR%" mkdir "%SCREENSHOT_DIR%"

REM 初始化测试结果
set TOTAL_TESTS=0
set PASSED_TESTS=0
set FAILED_TESTS=0

REM ============================================================
echo [阶段 1/7] 环境检查
echo ============================================================
echo.

REM 检查ADB
%ADB% version >nul 2>&1
if %errorlevel% neq 0 (
    echo [错误] ADB不可用
    goto :end
)
echo [OK] ADB可用

REM 检查设备连接
%ADB% devices | findstr "device$" >nul 2>&1
if %errorlevel% neq 0 (
    echo [错误] 没有连接的设备
    echo [提示] 请先运行 create-and-start-emulator.bat
    goto :end
)
echo [OK] 设备已连接

REM 检查APK文件
if not exist "%APK%" (
    echo [错误] APK文件不存在: %APK%
    echo [提示] 请先运行 build-smart.bat --project flutter --debug
    goto :end
)
echo [OK] APK文件存在

echo.
echo ============================================================
echo [阶段 2/7] 应用安装测试
echo ============================================================
echo.

REM 卸载旧版本
echo [测试 2.1] 卸载旧版本应用...
%ADB% uninstall %PACKAGE% >nul 2>&1
echo [OK] 旧版本已卸载

REM 安装APK
echo [测试 2.2] 安装APK...
%ADB% install "%APK%" >nul 2>&1
if %errorlevel% neq 0 (
    echo [失败] APK安装失败
    set /a FAILED_TESTS+=1
    goto :end
)
echo [通过] APK安装成功
set /a PASSED_TESTS+=1

REM 验证安装
echo [测试 2.3] 验证应用安装...
%ADB% shell pm list packages | findstr %PACKAGE% >nul 2>&1
if %errorlevel% neq 0 (
    echo [失败] 应用未在系统中找到
    set /a FAILED_TESTS+=1
) else (
    echo [通过] 应用已在系统中注册
    set /a PASSED_TESTS+=1
)
set /a TOTAL_TESTS+=2

REM 获取应用信息
echo [测试 2.4] 获取应用信息...
%ADB% shell dumpsys package %PACKAGE% | findstr "versionName" > "%REPORT_DIR%\app_info.txt"
echo [OK] 应用信息已保存

echo.
echo ============================================================
echo [阶段 3/7] 权限检查测试
echo ============================================================
echo.

REM 检查必要权限
echo [测试 3.1] 检查网络权限...
%ADB% shell dumpsys package %PACKAGE% | findstr "android.permission.INTERNET" >nul 2>&1
if %errorlevel% equ 0 (
    echo [通过] INTERNET权限已授予
    set /a PASSED_TESTS+=1
) else (
    echo [失败] INTERNET权限未授予
    set /a FAILED_TESTS+=1
)
set /a TOTAL_TESTS+=1

echo [测试 3.2] 检查通知权限...
%ADB% shell dumpsys package %PACKAGE% | findstr "android.permission.POST_NOTIFICATIONS" >nul 2>&1
if %errorlevel% equ 0 (
    echo [通过] POST_NOTIFICATIONS权限已声明
    set /a PASSED_TESTS+=1
) else (
    echo [失败] POST_NOTIFICATIONS权限未声明
    set /a FAILED_TESTS+=1
)
set /a TOTAL_TESTS+=1

echo [测试 3.3] 检查相机权限...
%ADB% shell dumpsys package %PACKAGE% | findstr "android.permission.CAMERA" >nul 2>&1
if %errorlevel% equ 0 (
    echo [通过] CAMERA权限已声明
    set /a PASSED_TESTS+=1
) else (
    echo [失败] CAMERA权限未声明
    set /a FAILED_TESTS+=1
)
set /a TOTAL_TESTS+=1

echo.
echo ============================================================
echo [阶段 4/7] 应用启动测试
echo ============================================================
echo.

REM 清除日志
%ADB% logcat -c

REM 启动应用
echo [测试 4.1] 启动应用...
%ADB% shell am start -n %PACKAGE%/.MainActivity >nul 2>&1

REM 等待应用启动
timeout /t 5 /nobreak >nul

REM 检查应用进程
%ADB% shell "ps -A | grep %PACKAGE%" >nul 2>&1
if %errorlevel% equ 0 (
    echo [通过] 应用进程运行中
    set /a PASSED_TESTS+=1
) else (
    echo [失败] 应用进程未找到
    set /a FAILED_TESTS+=1
)
set /a TOTAL_TESTS+=1

REM 截取启动屏幕
echo [测试 4.2] 截取启动屏幕...
%ADB% exec-out screencap -p > "%SCREENSHOT_DIR%\01_app_started.png"
echo [OK] 截图已保存

REM 检查应用崩溃
echo [测试 4.3] 检查应用崩溃...
%ADB% logcat -d -s AndroidRuntime:E | findstr "%PACKAGE%" >nul 2>&1
if %errorlevel% equ 0 (
    echo [失败] 检测到应用崩溃
    set /a FAILED_TESTS+=1
) else (
    echo [通过] 应用无崩溃
    set /a PASSED_TESTS+=1
)
set /a TOTAL_TESTS+=1

echo.
echo ============================================================
echo [阶段 5/7] 登录界面UI测试
echo ============================================================
echo.

REM 等待权限对话框处理
timeout /t 3 /nobreak >nul

REM 获取UI层级
echo [测试 5.1] 获取UI层级...
%ADB% shell uiautomator dump /sdcard/ui.xml >nul 2>&1
%ADB% shell cat /sdcard/ui.xml > "%REPORT_DIR%\ui_hierarchy.xml"

REM 检查登录界面元素
echo [测试 5.2] 检查应用标题...
findstr "SecChat" "%REPORT_DIR%\ui_hierarchy.xml" >nul 2>&1
if %errorlevel% equ 0 (
    echo [通过] 应用标题"SecChat"显示正常
    set /a PASSED_TESTS+=1
) else (
    echo [失败] 应用标题未找到
    set /a FAILED_TESTS+=1
)
set /a TOTAL_TESTS+=1

echo [测试 5.3] 检查副标题...
findstr "企业安全通讯平台" "%REPORT_DIR%\ui_hierarchy.xml" >nul 2>&1
if %errorlevel% equ 0 (
    echo [通过] 副标题显示正常
    set /a PASSED_TESTS+=1
) else (
    echo [失败] 副标题未找到
    set /a FAILED_TESTS+=1
)
set /a TOTAL_TESTS+=1

echo [测试 5.4] 检查登录按钮...
findstr "登录" "%REPORT_DIR%\ui_hierarchy.xml" >nul 2>&1
if %errorlevel% equ 0 (
    echo [通过] 登录按钮显示正常
    set /a PASSED_TESTS+=1
) else (
    echo [失败] 登录按钮未找到
    set /a FAILED_TESTS+=1
)
set /a TOTAL_TESTS+=1

echo [测试 5.5] 检查注册链接...
findstr "注册" "%REPORT_DIR%\ui_hierarchy.xml" >nul 2>&1
if %errorlevel% equ 0 (
    echo [通过] 注册链接显示正常
    set /a PASSED_TESTS+=1
) else (
    echo [失败] 注册链接未找到
    set /a FAILED_TESTS+=1
)
set /a TOTAL_TESTS+=1

echo [测试 5.6] 检查用户名输入框...
findstr "EditText" "%REPORT_DIR%\ui_hierarchy.xml" | findstr "password=\"false\"" >nul 2>&1
if %errorlevel% equ 0 (
    echo [通过] 用户名输入框存在
    set /a PASSED_TESTS+=1
) else (
    echo [失败] 用户名输入框未找到
    set /a FAILED_TESTS+=1
)
set /a TOTAL_TESTS+=1

echo [测试 5.7] 检查密码输入框...
findstr "EditText" "%REPORT_DIR%\ui_hierarchy.xml" | findstr "password=\"true\"" >nul 2>&1
if %errorlevel% equ 0 (
    echo [通过] 密码输入框存在
    set /a PASSED_TESTS+=1
) else (
    echo [失败] 密码输入框未找到
    set /a FAILED_TESTS+=1
)
set /a TOTAL_TESTS+=1

echo [测试 5.8] 检查服务器配置按钮...
findstr "服务器配置" "%REPORT_DIR%\ui_hierarchy.xml" >nul 2>&1
if %errorlevel% equ 0 (
    echo [通过] 服务器配置按钮存在
    set /a PASSED_TESTS+=1
) else (
    echo [失败] 服务器配置按钮未找到
    set /a FAILED_TESTS+=1
)
set /a TOTAL_TESTS+=1

REM 截取登录界面
%ADB% exec-out screencap -p > "%SCREENSHOT_DIR%\02_login_screen.png"

echo.
echo ============================================================
echo [阶段 6/7] 交互功能测试
echo ============================================================
echo.

echo [测试 6.1] 测试服务器配置对话框...
REM 点击设置按钮 (右上角)
%ADB% shell input tap 996 212
timeout /t 2 /nobreak >nul
%ADB% shell uiautomator dump /sdcard/ui.xml >nul 2>&1
%ADB% shell cat /sdcard/ui.xml > "%REPORT_DIR%\ui_server_config.xml"
findstr "服务器配置" "%REPORT_DIR%\ui_server_config.xml" >nul 2>&1
if %errorlevel% equ 0 (
    echo [通过] 服务器配置对话框打开成功
    set /a PASSED_TESTS+=1
    %ADB% exec-out screencap -p > "%SCREENSHOT_DIR%\03_server_config_dialog.png"
) else (
    echo [失败] 服务器配置对话框未打开
    set /a FAILED_TESTS+=1
)
set /a TOTAL_TESTS+=1

REM 关闭对话框
%ADB% shell input keyevent KEYCODE_BACK
timeout /t 1 /nobreak >nul

echo [测试 6.2] 测试用户名输入...
%ADB% shell input tap 540 1071
timeout /t 1 /nobreak >nul
%ADB% shell input text "testuser"
timeout /t 1 /nobreak >nul
echo [OK] 用户名输入测试完成

echo [测试 6.3] 测试密码输入...
%ADB% shell input tap 540 1260
timeout /t 1 /nobreak >nul
%ADB% shell input text "Test123456"
timeout /t 1 /nobreak >nul
echo [OK] 密码输入测试完成

%ADB% exec-out screencap -p > "%SCREENSHOT_DIR%\04_input_filled.png"

echo [测试 6.4] 测试表单验证（空值）...
REM 清空输入
%ADB% shell input keyevent KEYCODE_BACK
%ADB% shell am force-stop %PACKAGE%
timeout /t 2 /nobreak >nul
%ADB% shell am start -n %PACKAGE%/.MainActivity
timeout /t 5 /nobreak >nul

REM 直接点击登录按钮
%ADB% shell input tap 540 1469
timeout /t 2 /nobreak >nul
%ADB% exec-out screencap -p > "%SCREENSHOT_DIR%\05_validation_test.png"
echo [OK] 表单验证测试完成

echo.
echo ============================================================
echo [阶段 7/7] 注册页面测试
echo ============================================================
echo.

echo [测试 7.1] 导航到注册页面...
%ADB% shell input tap 540 1646
timeout /t 3 /nobreak >nul
%ADB% shell uiautomator dump /sdcard/ui.xml >nul 2>&1
%ADB% shell cat /sdcard/ui.xml > "%REPORT_DIR%\ui_register.xml"

findstr "注册" "%REPORT_DIR%\ui_register.xml" >nul 2>&1
if %errorlevel% equ 0 (
    echo [通过] 注册页面显示正常
    set /a PASSED_TESTS+=1
    %ADB% exec-out screencap -p > "%SCREENSHOT_DIR%\06_register_screen.png"
) else (
    echo [失败] 注册页面未正确显示
    set /a FAILED_TESTS+=1
)
set /a TOTAL_TESTS+=1

echo.
echo ============================================================
echo 测试完成！
echo ============================================================
echo.

REM 计算通过率
set /a PASS_RATE=PASSED_TESTS*100/TOTAL_TESTS

echo 测试结果摘要:
echo ------------------------------------------------------------
echo   总测试项: %TOTAL_TESTS%
echo   通过项: %PASSED_TESTS%
echo   失败项: %FAILED_TESTS%
echo   通过率: %PASS_RATE%%%
echo ------------------------------------------------------------
echo.

REM 保存测试报告
echo 生成测试报告...
(
echo # Android UI功能测试报告
echo.
echo ## 测试信息
echo - 测试日期: %date% %time%
echo - 应用包名: %PACKAGE%
echo - APK文件: %APK%
echo.
echo ## 测试结果摘要
echo - 总测试项: %TOTAL_TESTS%
echo - 通过项: %PASSED_TESTS%
echo - 失败项: %FAILED_TESTS%
echo - 通过率: %PASS_RATE%%%
echo.
echo ## 截图文件
echo - 01_app_started.png - 应用启动界面
echo - 02_login_screen.png - 登录界面
echo - 03_server_config_dialog.png - 服务器配置对话框
echo - 04_input_filled.png - 输入填充测试
echo - 05_validation_test.png - 表单验证测试
echo - 06_register_screen.png - 注册页面
) > "%REPORT_DIR%\test_summary.md"

echo [OK] 测试报告已保存到: %REPORT_DIR%\test_summary.md
echo.

:end
echo 按任意键退出...
pause >nul
