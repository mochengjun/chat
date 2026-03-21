# 快速启动指南 - Android应用测试

## 一、启动模拟器（3种方式）

### 方式1: 使用自动脚本（推荐）
```bash
# 双击运行或在命令行执行
create-and-start-emulator.bat
```
等待2-3分钟，直到看到"设备已连接"提示

### 方式2: 手动启动
```bash
# 1. 启动模拟器
start cmd /k "C:\Android\Sdk\emulator\emulator.exe" -avd Pixel_6_API_34

# 2. 等待30秒后检查设备
timeout /t 30
C:\Android\Sdk\platform-tools\adb.exe devices
```

### 方式3: 后台启动
```bash
# 后台启动模拟器
start /MIN C:\Android\Sdk\emulator\emulator.exe -avd Pixel_6_API_34 -no-boot-anim
```

## 二、验证环境

```bash
# 1. 检查设备连接
C:\Android\Sdk\platform-tools\adb.exe devices

# 预期输出:
# List of devices attached
# emulator-5554   device

# 2. 检查APK文件
dir installer\android\SecChat-debug.apk
```

## 三、安装应用

```bash
# 安装Debug版本APK
C:\Android\Sdk\platform-tools\adb.exe install installer\android\SecChat-debug.apk

# 预期输出: Success
```

## 四、启动应用

```bash
# 启动应用
C:\Android\Sdk\platform-tools\adb.exe shell am start -n com.example.sec_chat/.MainActivity
```

## 五、执行测试

### 自动化测试
```bash
# 运行Python测试脚本
python test_android_app.py

# 或使用批处理脚本
run_android_tests.bat
```

### 手动测试
参考文档: `ANDROID_EMULATOR_TEST_PLAN.md`

## 六、查看日志

```bash
# 查看Flutter日志
C:\Android\Sdk\platform-tools\adb.exe logcat -s flutter

# 保存日志到文件
C:\Android\Sdk\platform-tools\adb.exe logcat -s flutter > app_log.txt
```

## 七、截屏和录屏

```bash
# 截屏
C:\Android\Sdk\platform-tools\adb.exe shell screencap -p /sdcard/screenshot.png
C:\Android\Sdk\platform-tools\adb.exe pull /sdcard/screenshot.png

# 录屏（最长180秒）
C:\Android\Sdk\platform-tools\adb.exe shell screenrecord /sdcard/demo.mp4
# 按Ctrl+C停止录屏
C:\Android\Sdk\platform-tools\adb.exe pull /sdcard/demo.mp4
```

## 八、常用操作

```bash
# 卸载应用
C:\Android\Sdk\platform-tools\adb.exe uninstall com.example.sec_chat

# 清除应用数据
C:\Android\Sdk\platform-tools\adb.exe shell pm clear com.example.sec_chat

# 查看应用信息
C:\Android\Sdk\platform-tools\adb.exe shell dumpsys package com.example.sec_chat

# 查看设备信息
C:\Android\Sdk\platform-tools\adb.exe shell getprop ro.build.version.release
C:\Android\Sdk\platform-tools\adb.exe shell getprop ro.product.model
```

## 九、故障排查

### 问题1: 设备未连接
```bash
# 重启ADB服务
C:\Android\Sdk\platform-tools\adb.exe kill-server
C:\Android\Sdk\platform-tools\adb.exe start-server

# 重新检查设备
C:\Android\Sdk\platform-tools\adb.exe devices
```

### 问题2: 模拟器启动失败
```bash
# 检查AVD是否存在
C:\Android\Sdk\emulator\emulator.exe -list-avds

# 如果没有AVD，重新创建
# 运行: create-and-start-emulator.bat
```

### 问题3: APK安装失败
```bash
# 先卸载旧版本
C:\Android\Sdk\platform-tools\adb.exe uninstall com.example.sec_chat

# 重新安装
C:\Android\Sdk\platform-tools\adb.exe install installer\android\SecChat-debug.apk
```

### 问题4: 应用闪退
```bash
# 查看崩溃日志
C:\Android\Sdk\platform-tools\adb.exe logcat -s flutter AndroidRuntime:E *:F
```

## 十、测试报告

测试完成后，查看以下文件：
- 测试日志: `test_results.log`
- JSON报告: `test_report_*.json`
- Markdown报告: `test_report_*.md`
- 截图: `screenshots\`
- 应用日志: `logs\`

## 需要帮助？

查看详细文档：
- 测试计划: `ANDROID_EMULATOR_TEST_PLAN.md`
- 测试报告: `ANDROID_TEST_EXECUTION_REPORT.md`
- 测试总结: `ANDROID_TEST_SUMMARY.md`

---

**提示**: 如果模拟器启动困难，建议使用Android Studio的图形界面启动模拟器。
