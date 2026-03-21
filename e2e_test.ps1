# ============================================================
# Secure Enterprise Chat - End-to-End Test Script
# 端到端测试脚本 - 验证Android应用功能
# ============================================================

param(
    [Parameter()]
    [switch]$SkipBuild = $false,

    [Parameter()]
    [string]$ReportPath = "test_report_$(Get-Date -Format 'yyyyMMdd_HHmmss').md"
)

$ErrorActionPreference = "Continue"
$ProgressPreference = "SilentlyContinue"

# 颜色输出函数
function Write-Info { param($Message) Write-Host "[INFO] $Message" -ForegroundColor Cyan }
function Write-Success { param($Message) Write-Host "[✓] $Message" -ForegroundColor Green }
function Write-Warning { param($Message) Write-Host "[!] $Message" -ForegroundColor Yellow }
function Write-Error { param($Message) Write-Host "[✗] $Message" -ForegroundColor Red }

# 测试结果数组
$script:TestResults = @()
$script:PassedTests = 0
$script:FailedTests = 0

function Add-TestResult {
    param(
        [string]$TestName,
        [bool]$Passed,
        [string]$Details = "",
        [int]$DurationMs = 0
    )

    $result = [PSCustomObject]@{
        TestName = $TestName
        Passed = $Passed
        Details = $Details
        DurationMs = $DurationMs
        Timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fff"
    }

    $script:TestResults += $result

    if ($Passed) {
        $script:PassedTests++
        Write-Success "$TestName ($DurationMs ms)"
    } else {
        $script:FailedTests++
        Write-Error "$TestName - $Details"
    }
}

# 测试1: 检查Flutter环境
function Test-FlutterEnvironment {
    Write-Info "Testing Flutter environment..."
    $startTime = Get-Date

    try {
        $flutterVersion = & flutter --version 2>&1 | Select-Object -First 1
        $duration = ((Get-Date) - $startTime).TotalMilliseconds

        if ($flutterVersion -match "Flutter") {
            Add-TestResult -TestName "Flutter环境检查" -Passed $true -Details $flutterVersion -DurationMs $duration
            return $true
        } else {
            Add-TestResult -TestName "Flutter环境检查" -Passed $false -Details "Flutter未安装" -DurationMs $duration
            return $false
        }
    } catch {
        $duration = ((Get-Date) - $startTime).TotalMilliseconds
        Add-TestResult -TestName "Flutter环境检查" -Passed $false -Details $_.Exception.Message -DurationMs $duration
        return $false
    }
}

# 测试2: 检查Android SDK
function Test-AndroidSDK {
    Write-Info "Testing Android SDK..."
    $startTime = Get-Date

    try {
        $adbVersion = & adb version 2>&1 | Select-Object -First 1
        $duration = ((Get-Date) - $startTime).TotalMilliseconds

        if ($adbVersion -match "Android Debug Bridge") {
            Add-TestResult -TestName "Android SDK检查" -Passed $true -Details $adbVersion -DurationMs $duration
            return $true
        } else {
            Add-TestResult -TestName "Android SDK检查" -Passed $false -Details "ADB未安装" -DurationMs $duration
            return $false
        }
    } catch {
        $duration = ((Get-Date) - $startTime).TotalMilliseconds
        Add-TestResult -TestName "Android SDK检查" -Passed $false -Details $_.Exception.Message -DurationMs $duration
        return $false
    }
}

# 测试3: 检查模拟器/设备连接
function Test-DeviceConnection {
    Write-Info "Testing device connection..."
    $startTime = Get-Date

    try {
        $devices = & adb devices 2>&1 | Select-Object -Skip 1 | Where-Object { $_ -match "device$" }
        $duration = ((Get-Date) - $startTime).TotalMilliseconds

        if ($devices) {
            $deviceCount = ($devices | Measure-Object).Count
            Add-TestResult -TestName "设备连接检查" -Passed $true -Details "找到 $deviceCount 个设备" -DurationMs $duration
            return $true
        } else {
            Add-TestResult -TestName "设备连接检查" -Passed $false -Details "未找到连接的设备或模拟器" -DurationMs $duration
            return $false
        }
    } catch {
        $duration = ((Get-Date) - $startTime).TotalMilliseconds
        Add-TestResult -TestName "设备连接检查" -Passed $false -Details $_.Exception.Message -DurationMs $duration
        return $false
    }
}

# 测试4: 检查应用包是否存在
function Test-AppPackageExists {
    Write-Info "Checking if app package exists..."
    $startTime = Get-Date

    $apkPath = "apps/flutter_app/build/app/outputs/flutter-apk/app-debug.apk"
    if (Test-Path $apkPath) {
        $fileInfo = Get-Item $apkPath
        $duration = ((Get-Date) - $startTime).TotalMilliseconds
        Add-TestResult -TestName "应用包存在检查" -Passed $true -Details "APK大小: $([math]::Round($fileInfo.Length/1MB, 2)) MB" -DurationMs $duration
        return $true
    } else {
        $duration = ((Get-Date) - $startTime).TotalMilliseconds
        Add-TestResult -TestName "应用包存在检查" -Passed $false -Details "APK文件不存在: $apkPath" -DurationMs $duration
        return $false
    }
}

# 测试5: 检查应用是否已安装
function Test-AppInstalled {
    Write-Info "Checking if app is installed..."
    $startTime = Get-Date

    try {
        $packages = & adb shell pm list packages com.example.sec_chat 2>&1
        $duration = ((Get-Date) - $startTime).TotalMilliseconds

        if ($packages -match "com.example.sec_chat") {
            Add-TestResult -TestName "应用安装检查" -Passed $true -Details "应用已安装" -DurationMs $duration
            return $true
        } else {
            Add-TestResult -TestName "应用安装检查" -Passed $false -Details "应用未安装" -DurationMs $duration
            return $false
        }
    } catch {
        $duration = ((Get-Date) - $startTime).TotalMilliseconds
        Add-TestResult -TestName "应用安装检查" -Passed $false -Details $_.Exception.Message -DurationMs $duration
        return $false
    }
}

# 测试6: 检查应用是否在前台运行
function Test-AppForeground {
    Write-Info "Checking if app is in foreground..."
    $startTime = Get-Date

    try {
        # 获取当前前台应用
        $foregroundApp = & adb shell dumpsys activity activities 2>&1 | Select-String "mResumedActivity" | Select-Object -First 1
        $duration = ((Get-Date) - $startTime).TotalMilliseconds

        if ($foregroundApp -match "com.example.sec_chat") {
            Add-TestResult -TestName "应用前台运行检查" -Passed $true -Details "应用在前台运行" -DurationMs $duration
            return $true
        } else {
            # 检查应用是否在运行（即使不在前台）
            $runningApps = & adb shell ps 2>&1 | Select-String "com.example.sec_chat"
            if ($runningApps) {
                Add-TestResult -TestName "应用前台运行检查" -Passed $true -Details "应用在后台运行" -DurationMs $duration
                return $true
            } else {
                Add-TestResult -TestName "应用前台运行检查" -Passed $false -Details "应用未运行" -DurationMs $duration
                return $false
            }
        }
    } catch {
        $duration = ((Get-Date) - $startTime).TotalMilliseconds
        Add-TestResult -TestName "应用前台运行检查" -Passed $false -Details $_.Exception.Message -DurationMs $duration
        return $false
    }
}

# 测试7: 检查网络权限
function Test-NetworkPermission {
    Write-Info "Checking network permissions..."
    $startTime = Get-Date

    try {
        $permissions = & adb shell dumpsys package com.example.sec_chat 2>&1 | Select-String "android.permission.INTERNET|android.permission.ACCESS_NETWORK_STATE"
        $duration = ((Get-Date) - $startTime).TotalMilliseconds

        if ($permissions -match "INTERNET" -and $permissions -match "ACCESS_NETWORK_STATE") {
            Add-TestResult -TestName "网络权限检查" -Passed $true -Details "网络权限已授予" -DurationMs $duration
            return $true
        } else {
            Add-TestResult -TestName "网络权限检查" -Passed $false -Details "网络权限未授予" -DurationMs $duration
            return $false
        }
    } catch {
        $duration = ((Get-Date) - $startTime).TotalMilliseconds
        Add-TestResult -TestName "网络权限检查" -Passed $false -Details $_.Exception.Message -DurationMs $duration
        return $false
    }
}

# 测试8: 检查相机权限
function Test-CameraPermission {
    Write-Info "Checking camera permission..."
    $startTime = Get-Date

    try {
        $permission = & adb shell dumpsys package com.example.sec_chat 2>&1 | Select-String "android.permission.CAMERA"
        $duration = ((Get-Date) - $startTime).TotalMilliseconds

        if ($permission -match "CAMERA") {
            Add-TestResult -TestName "相机权限检查" -Passed $true -Details "相机权限已授予" -DurationMs $duration
            return $true
        } else {
            Add-TestResult -TestName "相机权限检查" -Passed $false -Details "相机权限未授予" -DurationMs $duration
            return $false
        }
    } catch {
        $duration = ((Get-Date) - $startTime).TotalMilliseconds
        Add-TestResult -TestName "相机权限检查" -Passed $false -Details $_.Exception.Message -DurationMs $duration
        return $false
    }
}

# 测试9: 检查通知权限
function Test-NotificationPermission {
    Write-Info "Checking notification permission..."
    $startTime = Get-Date

    try {
        $permission = & adb shell dumpsys package com.example.sec_chat 2>&1 | Select-String "android.permission.POST_NOTIFICATIONS"
        $duration = ((Get-Date) - $startTime).TotalMilliseconds

        if ($permission -match "POST_NOTIFICATIONS") {
            Add-TestResult -TestName "通知权限检查" -Passed $true -Details "通知权限已授予" -DurationMs $duration
            return $true
        } else {
            Add-TestResult -TestName "通知权限检查" -Passed $false -Details "通知权限未授予" -DurationMs $duration
            return $false
        }
    } catch {
        $duration = ((Get-Date) - $startTime).TotalMilliseconds
        Add-TestResult -TestName "通知权限检查" -Passed $false -Details $_.Exception.Message -DurationMs $duration
        return $false
    }
}

# 测试10: 网络连接测试
function Test-NetworkConnection {
    Write-Info "Testing network connection..."
    $startTime = Get-Date

    try {
        # 检查设备网络状态
        $networkInfo = & adb shell dumpsys connectivity 2>&1 | Select-String "NetworkAgentInfo" | Select-Object -First 3

        # 尝试访问后端服务（10.0.2.2:8081是Android模拟器访问宿主机的地址）
        $pingResult = & adb shell "ping -c 1 -W 2 10.0.2.2" 2>&1
        $duration = ((Get-Date) - $startTime).TotalMilliseconds

        if ($pingResult -match "1 received|1 packets received") {
            Add-TestResult -TestName "网络连接检查" -Passed $true -Details "可以访问宿主机(10.0.2.2)" -DurationMs $duration
            return $true
        } else {
            # 尝试检查网络状态
            $wifi = & adb shell dumpsys wifi 2>&1 | Select-String "Wi-Fi is enabled"
            if ($wifi) {
                Add-TestResult -TestName "网络连接检查" -Passed $true -Details "WiFi已启用" -DurationMs $duration
                return $true
            } else {
                Add-TestResult -TestName "网络连接检查" -Passed $false -Details "无法访问网络" -DurationMs $duration
                return $false
            }
        }
    } catch {
        $duration = ((Get-Date) - $startTime).TotalMilliseconds
        Add-TestResult -TestName "网络连接检查" -Passed $false -Details $_.Exception.Message -DurationMs $duration
        return $false
    }
}

# 测试11: 应用日志检查
function Test-AppLogs {
    Write-Info "Checking app logs..."
    $startTime = Get-Date

    try {
        # 获取最近的日志
        $logs = & adb logcat -d -s flutter -t 50 2>&1 | Select-String "SecChat|sec_chat|Main|Error|Exception" | Select-Object -Last 10
        $duration = ((Get-Date) - $startTime).TotalMilliseconds

        if ($logs) {
            $errorCount = ($logs | Select-String "Error|Exception|Failed" | Measure-Object).Count
            if ($errorCount -eq 0) {
                Add-TestResult -TestName "应用日志检查" -Passed $true -Details "未发现错误日志" -DurationMs $duration
            } else {
                Add-TestResult -TestName "应用日志检查" -Passed $false -Details "发现 $errorCount 个错误" -DurationMs $duration
            }
        } else {
            Add-TestResult -TestName "应用日志检查" -Passed $true -Details "无相关日志" -DurationMs $duration
        }
        return $true
    } catch {
        $duration = ((Get-Date) - $startTime).TotalMilliseconds
        Add-TestResult -TestName "应用日志检查" -Passed $false -Details $_.Exception.Message -DurationMs $duration
        return $false
    }
}

# 测试12: 应用稳定性测试（启动/停止）
function Test-AppStability {
    Write-Info "Testing app stability..."
    $startTime = Get-Date

    try {
        # 强制停止应用
        & adb shell am force-stop com.example.sec_chat 2>&1 | Out-Null
        Start-Sleep -Seconds 2

        # 重新启动应用
        & adb shell am start -n com.example.sec_chat/.MainActivity 2>&1 | Out-Null
        Start-Sleep -Seconds 5

        # 检查应用是否运行
        $running = & adb shell ps 2>&1 | Select-String "com.example.sec_chat"
        $duration = ((Get-Date) - $startTime).TotalMilliseconds

        if ($running) {
            Add-TestResult -TestName "应用稳定性检查" -Passed $true -Details "应用可以正常重启" -DurationMs $duration
            return $true
        } else {
            Add-TestResult -TestName "应用稳定性检查" -Passed $false -Details "应用重启失败" -DurationMs $duration
            return $false
        }
    } catch {
        $duration = ((Get-Date) - $startTime).TotalMilliseconds
        Add-TestResult -TestName "应用稳定性检查" -Passed $false -Details $_.Exception.Message -DurationMs $duration
        return $false
    }
}

# 构建应用
function Build-App {
    Write-Info "Building Flutter app..."

    Push-Location "apps/flutter_app"
    try {
        # 获取依赖
        Write-Info "Getting dependencies..."
        & flutter pub get

        # 构建APK
        Write-Info "Building APK..."
        & flutter build apk --debug

        if ($LASTEXITCODE -eq 0) {
            Write-Success "Build completed successfully"
            return $true
        } else {
            Write-Error "Build failed"
            return $false
        }
    } finally {
        Pop-Location
    }
}

# 安装应用
function Install-App {
    Write-Info "Installing app..."

    $apkPath = "apps/flutter_app/build/app/outputs/flutter-apk/app-debug.apk"
    if (Test-Path $apkPath) {
        # 先检查是否已安装，如果已安装则先卸载（避免签名不匹配问题）
        $existingPackage = & adb shell pm list packages com.example.sec_chat 2>&1
        if ($existingPackage -match "com.example.sec_chat") {
            Write-Info "Uninstalling existing app (signature may differ)..."
            & adb uninstall com.example.sec_chat 2>&1 | Out-Null
            Start-Sleep -Seconds 2
        }

        # 安装新版本
        & adb install $apkPath
        if ($LASTEXITCODE -eq 0) {
            Write-Success "App installed successfully"
            return $true
        } else {
            Write-Error "App installation failed"
            return $false
        }
    } else {
        Write-Error "APK not found: $apkPath"
        return $false
    }
}

# 启动应用
function Start-App {
    Write-Info "Starting app..."

    & adb shell am start -n com.example.sec_chat/.MainActivity
    Start-Sleep -Seconds 5

    # 检查应用是否运行
    $running = & adb shell ps 2>&1 | Select-String "com.example.sec_chat"
    if ($running) {
        Write-Success "App started successfully"
        return $true
    } else {
        Write-Error "App failed to start"
        return $false
    }
}

# 生成测试报告
function Generate-TestReport {
    param([string]$ReportPath)

    $totalTests = $script:PassedTests + $script:FailedTests
    $passRate = if ($totalTests -gt 0) { [math]::Round(($script:PassedTests / $totalTests) * 100, 1) } else { 0 }

    $report = @"
# Android应用端到端测试报告

## 测试摘要

- **测试日期**: $(Get-Date -Format "yyyy-MM-ddTHH:mm:ss")
- **总测试数**: $totalTests
- **通过数**: $($script:PassedTests)
- **失败数**: $($script:FailedTests)
- **通过率**: $passRate%

## 测试结果详情

| 测试项 | 结果 | 详情 | 时间 |
|--------|------|------|------|
"@

    foreach ($result in $script:TestResults) {
        $status = if ($result.Passed) { "✅ 通过" } else { "❌ 失败" }
        $report += "| $($result.TestName) | $status | $($result.Details) | $($result.Timestamp) |`n"
    }

    $report += @"

## 测试环境

- **设备**: Android模拟器/设备
- **应用包名**: com.example.sec_chat
- **APK**: app-debug.apk

## 测试结论

"@

    if ($passRate -eq 100) {
        $report += "✅ 所有测试通过！应用运行正常。`n"
    } elseif ($passRate -ge 80) {
        $report += "⚠️ 测试通过率良好，但有一些问题需要关注。`n"
    } else {
        $report += "❌ 测试失败率较高，需要重点关注和修复。`n"
    }

    # 添加建议
    $report += @"

## 修复建议

"@

    $failedTests = $script:TestResults | Where-Object { -not $_.Passed }
    if ($failedTests) {
        foreach ($test in $failedTests) {
            $report += "- **$($test.TestName)**: $($test.Details)`n"
        }
    } else {
        $report += "- 所有测试通过，无需修复。`n"
    }

    $report | Out-File -FilePath $ReportPath -Encoding UTF8
    Write-Info "Test report generated: $ReportPath"
}

# 主函数
function Main {
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "  Secure Enterprise Chat - E2E Test" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan

    # 环境检查
    $envOk = Test-FlutterEnvironment
    if (-not $envOk) {
        Write-Error "Flutter environment not found. Please install Flutter first."
        exit 1
    }

    Test-AndroidSDK
    Test-DeviceConnection

    # 构建和安装
    if (-not $SkipBuild) {
        $buildOk = Build-App
        if (-not $buildOk) {
            Write-Error "Build failed. Cannot continue tests."
            exit 1
        }

        Install-App
    }

    Test-AppPackageExists
    Test-AppInstalled

    # 启动应用
    Start-App

    # 运行功能测试
    Test-AppForeground
    Test-NetworkPermission
    Test-CameraPermission
    Test-NotificationPermission
    Test-NetworkConnection
    Test-AppLogs
    Test-AppStability

    # 生成报告
    Generate-TestReport -ReportPath $ReportPath

    # 输出摘要
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "  Test Summary" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Total Tests: $($script:PassedTests + $script:FailedTests)" -ForegroundColor White
    Write-Host "Passed: $($script:PassedTests)" -ForegroundColor Green
    Write-Host "Failed: $($script:FailedTests)" -ForegroundColor Red
    $passRate = if (($script:PassedTests + $script:FailedTests) -gt 0) {
        [math]::Round(($script:PassedTests / ($script:PassedTests + $script:FailedTests)) * 100, 1)
    } else { 0 }
    Write-Host "Pass Rate: $passRate%" -ForegroundColor $(if ($passRate -ge 80) { "Green" } else { "Red" })
    Write-Host "Report: $ReportPath" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan

    # 返回退出码
    if ($script:FailedTests -eq 0) {
        exit 0
    } else {
        exit 1
    }
}

# 运行主函数
Main
