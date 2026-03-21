# Android应用测试故障排除指南

## 测试失败分析

基于2026-03-19的测试结果，以下两个关键测试项失败：

| 测试项 | 结果 | 详情 | 时间 |
|--------|------|------|------|
| 应用启动 | ❌ 失败 | 应用未在前台运行 | 2026-03-19T11:35:22.791364 |
| 网络连接 | ❌ 失败 | 网络连接失败 | 2026-03-19T11:35:33.142054 |

---

## 问题1: 应用启动失败（应用未在前台运行）

### 1.1 问题描述
测试脚本执行了启动命令，但应用未能正确进入前台运行状态。

### 1.2 可能原因分析

#### 原因A: 模拟器未完全启动
- **症状**: 设备已连接但系统服务未完全初始化
- **检测**: 模拟器窗口显示黑屏或正在启动动画

#### 原因B: 应用包名或Activity名称错误
- **症状**: 启动命令执行但找不到对应组件
- **检测**: ADB返回`Activity not found`错误

#### 原因C: 应用安装失败或APK损坏
- **症状**: 应用未正确安装到设备
- **检测**: 包列表中找不到应用

#### 原因D: 应用启动后崩溃
- **症状**: 应用启动后立即退出
- **检测**: Logcat显示崩溃堆栈

#### 原因E: 模拟器系统镜像不完整
- **症状**: 系统组件缺失导致应用无法运行
- **检测**: 系统日志显示资源加载失败

### 1.3 诊断步骤

#### 步骤1: 验证模拟器状态
```powershell
# 检查设备是否完全启动
C:\Android\Sdk\platform-tools\adb.exe shell getprop sys.boot_completed
# 应返回: 1

# 检查系统服务状态
C:\Android\Sdk\platform-tools\adb.exe shell getprop init.svc.bootanim
# 应返回: stopped
```

#### 步骤2: 验证应用安装状态
```powershell
# 检查应用是否已安装
C:\Android\Sdk\platform-tools\adb.exe shell pm list packages | findstr sec_chat
# 应返回: package:com.example.sec_chat

# 检查应用详细信息
C:\Android\Sdk\platform-tools\adb.exe shell dumpsys package com.example.sec_chat
```

#### 步骤3: 检查Activity名称
```powershell
# 查看应用的Activity列表
C:\Android\Sdk\platform-tools\adb.exe shell cmd package resolve-activity -c android.intent.category.LAUNCHER com.example.sec_chat

# 或查看所有Activity
C:\Android\Sdk\platform-tools\adb.exe shell dumpsys package com.example.sec_chat | findstr Activity
```

#### 步骤4: 查看应用日志
```powershell
# 清除日志缓冲区
C:\Android\Sdk\platform-tools\adb.exe logcat -c

# 启动应用并捕获日志
C:\Android\Sdk\platform-tools\adb.exe shell am start -n com.example.sec_chat/.MainActivity

# 等待5秒后查看日志
C:\Android\Sdk\platform-tools\adb.exe logcat -d -s flutter:* AndroidRuntime:*
```

#### 步骤5: 手动测试启动
```powershell
# 使用monkey测试应用是否能启动
C:\Android\Sdk\platform-tools\adb.exe shell monkey -p com.example.sec_chat -c android.intent.category.LAUNCHER 1

# 检查前台Activity
C:\Android\Sdk\platform-tools\adb.exe shell dumpsys activity activities | findstr mResumedActivity
```

### 1.4 解决方案

#### 方案A: 等待模拟器完全启动
```powershell
# 重启模拟器并等待完全启动
C:\Android\Sdk\platform-tools\adb.exe reboot

# 等待启动完成（约2-3分钟）
:wait_loop
timeout /t 5 /nobreak >nul
C:\Android\Sdk\platform-tools\adb.exe shell getprop sys.boot_completed | findstr "1" >nul
if errorlevel 1 goto wait_loop
echo 模拟器已完全启动
```

#### 方案B: 重新安装APK
```powershell
# 卸载旧版本
C:\Android\Sdk\platform-tools\adb.exe uninstall com.example.sec_chat

# 重新安装
C:\Android\Sdk\platform-tools\adb.exe install -r "installer\android\SecChat-debug.apk"

# 验证安装
C:\Android\Sdk\platform-tools\adb.exe shell pm list packages | findstr sec_chat
```

#### 方案C: 使用正确的Activity名称
如果`.MainActivity`不正确，尝试以下命令：
```powershell
# 查找正确的启动Activity
C:\Android\Sdk\platform-tools\adb.exe shell cmd package resolve-activity --brief com.example.sec_chat

# 使用完整Activity名称启动
C:\Android\Sdk\platform-tools\adb.exe shell am start -n com.example.sec_chat/com.example.sec_chat.MainActivity
```

#### 方案D: 修复模拟器系统镜像
```powershell
# 删除并重新创建AVD
C:\Android\Sdk\emulator\emulator.exe -avd Pixel_6_API_34 -wipe-data

# 或重新创建AVD
cd %USERPROFILE%\.android\avd
rmdir /S /Q Pixel_6_API_34.avd
del Pixel_6_API_34.ini

# 然后重新运行创建脚本
create-and-start-emulator.bat
```

#### 方案E: 检查Flutter应用配置
检查 `apps/flutter_app/android/app/src/main/AndroidManifest.xml` 中的主Activity配置：
```xml
<activity
    android:name=".MainActivity"
    android:launchMode="singleTop"
    android:theme="@style/LaunchTheme"
    ...>
    <intent-filter>
        <action android:name="android.intent.action.MAIN"/>
        <category android:name="android.intent.category.LAUNCHER"/>
    </intent-filter>
</activity>
```

### 1.5 验证修复

```powershell
# 1. 确认设备连接
C:\Android\Sdk\platform-tools\adb.exe devices

# 2. 确认应用已安装
C:\Android\Sdk\platform-tools\adb.exe shell pm list packages | findstr sec_chat

# 3. 启动应用
C:\Android\Sdk\platform-tools\adb.exe shell am start -n com.example.sec_chat/.MainActivity

# 4. 等待3秒

# 5. 检查前台Activity
C:\Android\Sdk\platform-tools\adb.exe shell dumpsys activity activities | findstr mResumedActivity
# 应包含: com.example.sec_chat

# 6. 截屏验证
C:\Android\Sdk\platform-tools\adb.exe shell screencap -p /sdcard/verify.png
C:\Android\Sdk\platform-tools\adb.exe pull /sdcard/verify.png
```

---

## 问题2: 网络连接失败

### 2.1 问题描述
测试脚本执行 `ping -c 1 8.8.8.8` 失败，无法连接外部网络。

### 2.2 可能原因分析

#### 原因A: 模拟器网络未启用
- **症状**: 模拟器没有网络连接
- **检测**: 设置中显示无网络

#### 原因B: DNS解析问题
- **症状**: ping IP地址失败
- **检测**: 无法解析任何域名

#### 原因C: 防火墙阻止
- **症状**: 特定端口或协议被阻止
- **检测**: 部分网络服务可用

#### 原因D: 主机网络问题
- **症状**: 主机本身无法访问外网
- **检测**: 主机浏览器无法打开网页

#### 原因E: 模拟器DNS配置错误
- **症状**: 需要配置正确的DNS服务器
- **检测**: ping IP成功但ping域名失败

### 2.3 诊断步骤

#### 步骤1: 检查主机网络
```powershell
# 在主机上测试网络连接
ping 8.8.8.8
ping www.google.com

# 检查网络适配器状态
ipconfig /all
```

#### 步骤2: 检查模拟器网络状态
```powershell
# 检查模拟器网络接口
C:\Android\Sdk\platform-tools\adb.exe shell ifconfig

# 检查路由表
C:\Android\Sdk\platform-tools\adb.exe shell ip route

# 检查DNS配置
C:\Android\Sdk\platform-tools\adb.exe shell getprop net.dns1
C:\Android\Sdk\platform-tools\adb.exe shell getprop net.dns2
```

#### 步骤3: 测试不同类型的网络连接
```powershell
# 测试ping到网关（模拟器内部）
C:\Android\Sdk\platform-tools\adb.exe shell ping -c 1 10.0.2.2

# 测试ping到Google DNS
C:\Android\Sdk\platform-tools\adb.exe shell ping -c 1 8.8.8.8

# 测试ping到百度（国内）
C:\Android\Sdk\platform-tools\adb.exe shell ping -c 1 114.114.114.114

# 测试HTTP连接
C:\Android\Sdk\platform-tools\adb.exe shell curl -I http://www.google.com
```

#### 步骤4: 检查应用网络权限
```powershell
# 检查应用网络权限
C:\Android\Sdk\platform-tools\adb.exe shell dumpsys package com.example.sec_chat | findstr INTERNET
C:\Android\Sdk\platform-tools\adb.exe shell dumpsys package com.example.sec_chat | findstr NETWORK
```

### 2.4 解决方案

#### 方案A: 重启模拟器网络
```powershell
# 关闭并重新启用模拟器WiFi（通过设置界面）
# 或使用ADB命令切换飞行模式
C:\Android\Sdk\platform-tools\adb.exe shell settings put global airplane_mode_on 1
C:\Android\Sdk\platform-tools\adb.exe shell am broadcast -a android.intent.action.AIRPLANE_MODE

timeout /t 2 /nobreak >nul

C:\Android\Sdk\platform-tools\adb.exe shell settings put global airplane_mode_on 0
C:\Android\Sdk\platform-tools\adb.exe shell am broadcast -a android.intent.action.AIRPLANE_MODE
```

#### 方案B: 配置DNS服务器
```powershell
# 设置DNS服务器（需要root权限）
C:\Android\Sdk\platform-tools\adb.exe shell setprop net.dns1 8.8.8.8
C:\Android\Sdk\platform-tools\adb.exe shell setprop net.dns2 8.8.4.4

# 或使用国内DNS
C:\Android\Sdk\platform-tools\adb.exe shell setprop net.dns1 114.114.114.114
C:\Android\Sdk\platform-tools\adb.exe shell setprop net.dns2 223.5.5.5
```

#### 方案C: 使用模拟器参数启动
```powershell
# 使用-dns-server参数启动模拟器
taskkill /F /IM emulator.exe /T 2>nul
timeout /t 3 /nobreak >nul

start "Android Emulator" /MIN "C:\Android\Sdk\emulator\emulator.exe" -avd Pixel_6_API_34 -dns-server 8.8.8.8,8.8.4.4

# 等待设备连接
:wait_loop
timeout /t 2 /nobreak >nul
C:\Android\Sdk\platform-tools\adb.exe devices | findstr "device$" >nul
if errorlevel 1 goto wait_loop

echo 模拟器已启动，DNS已配置
```

#### 方案D: 修改测试脚本（使用本地网络测试）
如果外部网络不可用，修改测试脚本使用本地网络测试：

```python
# 在 test_android_app.py 中修改网络测试部分
# 原代码:
# success, stdout, _ = self.run_command(
#     f'"{self.adb_path}" shell ping -c 1 8.8.8.8'
# )

# 修改为使用模拟器网关测试:
success, stdout, _ = self.run_command(
    f'"{self.adb_path}" shell ping -c 1 10.0.2.2'
)

# 或检查网络接口状态:
success, stdout, _ = self.run_command(
    f'"{self.adb_path}" shell ifconfig eth0'
)
if success and "UP" in stdout:
    network_ok = True
```

#### 方案E: 使用HTTP测试替代ping
```python
# 修改网络测试方法
def test_network_connection(self):
    """测试网络连接 - 使用多种方法"""
    self.log("\n测试3: 网络连接测试")
    
    # 方法1: 检查网络接口状态
    success, stdout, _ = self.run_command(
        f'"{self.adb_path}" shell ifconfig eth0'
    )
    if success and "UP" in stdout:
        self.record_test_result("网络连接", True, "网络接口已启用")
        return
    
    # 方法2: 测试ping到网关
    success, stdout, _ = self.run_command(
        f'"{self.adb_path}" shell ping -c 1 10.0.2.2'
    )
    if success:
        self.record_test_result("网络连接", True, "本地网络连接正常")
        return
    
    # 方法3: 测试外部DNS
    success, stdout, _ = self.run_command(
        f'"{self.adb_path}" shell ping -c 1 114.114.114.114'
    )
    if success:
        self.record_test_result("网络连接", True, "外部网络连接正常")
        return
    
    self.record_test_result("网络连接", False, "网络连接失败")
```

### 2.5 验证修复

```powershell
# 1. 检查网络接口
C:\Android\Sdk\platform-tools\adb.exe shell ifconfig

# 2. 测试ping到网关
C:\Android\Sdk\platform-tools\adb.exe shell ping -c 3 10.0.2.2

# 3. 测试ping到外部DNS
C:\Android\Sdk\platform-tools\adb.exe shell ping -c 3 8.8.8.8

# 4. 测试HTTP连接
C:\Android\Sdk\platform-tools\adb.exe shell curl -s --max-time 10 http://www.google.com | head -5

# 5. 检查DNS解析
C:\Android\Sdk\platform-tools\adb.exe shell nslookup www.google.com
```

---

## 综合修复脚本

创建一个自动化修复脚本 `fix_android_test_issues.bat`：

```batch
@echo off
REM ============================================================
REM Android测试问题自动修复脚本
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
    echo        运行: create-and-start-emulator.bat
    pause
    exit /b 1
)
echo [OK] 设备已连接

REM 等待设备完全启动
echo.
echo [步骤 3/6] 等待设备完全启动...
set /a WAIT_COUNT=0
:wait_boot
%ADB% shell getprop sys.boot_completed | findstr "1" >nul
if not errorlevel 1 goto boot_complete
set /a WAIT_COUNT+=1
if %WAIT_COUNT% geq 30 (
    echo [错误] 等待设备启动超时
    pause
    exit /b 1
)
echo   等待设备启动... (%WAIT_COUNT%/30)
timeout /t 2 /nobreak >nul
goto wait_boot
:boot_complete
echo [OK] 设备已完全启动

REM 修复网络连接
echo.
echo [步骤 4/6] 修复网络连接...
%ADB% shell setprop net.dns1 114.114.114.114
%ADB% shell setprop net.dns2 223.5.5.5
echo [OK] DNS服务器已配置

REM 重新安装应用
echo.
echo [步骤 5/6] 重新安装应用...
%ADB% shell pm list packages | findstr "%PACKAGE%" >nul
if not errorlevel 1 (
    echo   卸载旧版本...
    %ADB% uninstall %PACKAGE%
)
echo   安装新版本...
%ADB% install -r "%APK%"
if errorlevel 1 (
    echo [错误] 安装失败
    pause
    exit /b 1
)
echo [OK] 应用安装成功

REM 验证修复
echo.
echo [步骤 6/6] 验证修复结果...
echo   启动应用...
%ADB% shell am start -n %PACKAGE%/.MainActivity
timeout /t 3 /nobreak >nul

echo   检查应用状态...
%ADB% shell dumpsys activity activities | findstr mResumedActivity | findstr "%PACKAGE%" >nul
if not errorlevel 1 (
    echo [OK] 应用已成功启动并运行在前台
) else (
    echo [警告] 应用可能未在前台运行
)

echo   测试网络连接...
%ADB% shell ping -c 1 10.0.2.2 >nul 2>&1
if not errorlevel 1 (
    echo [OK] 网络连接正常
) else (
    echo [警告] 网络连接可能有问题
)

echo.
echo ============================================================
echo    修复完成！
echo ============================================================
echo.
echo 现在可以重新运行测试:
echo   python test_android_app.py
echo.

pause
```

---

## 重新测试步骤

修复完成后，按以下步骤重新执行测试：

### 步骤1: 运行修复脚本
```powershell
fix_android_test_issues.bat
```

### 步骤2: 执行测试
```powershell
python test_android_app.py
```

### 步骤3: 查看测试结果
```powershell
# 查看生成的报告
type test_report_*.md

# 查看详细日志
type test_results.log
```

### 步骤4: 手动验证（如自动化测试仍失败）
```powershell
# 1. 启动应用
C:\Android\Sdk\platform-tools\adb.exe shell am start -n com.example.sec_chat/.MainActivity

# 2. 等待5秒
timeout /t 5 /nobreak >nul

# 3. 截屏
C:\Android\Sdk\platform-tools\adb.exe shell screencap -p /sdcard/manual_test.png
C:\Android\Sdk\platform-tools\adb.exe pull /sdcard/manual_test.png

# 4. 查看日志
C:\Android\Sdk\platform-tools\adb.exe logcat -d -s flutter:* > manual_test_log.txt
```

---

## 长期改进建议

### 1. 测试脚本改进
- 增加重试机制
- 添加更详细的错误日志
- 使用多种网络测试方法
- 增加模拟器状态检查

### 2. 环境配置改进
- 使用固定的DNS配置启动模拟器
- 配置模拟器使用主机网络代理
- 准备离线测试模式

### 3. CI/CD集成
- 在GitHub Actions中配置Android测试
- 使用Firebase Test Lab进行云测试
- 集成测试报告自动上传

---

**文档版本**: 1.0  
**创建日期**: 2026-03-19  
**最后更新**: 2026-03-19
