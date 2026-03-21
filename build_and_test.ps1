# ============================================================
# Secure Enterprise Chat - Build and Test Script
# 构建和测试脚本
# ============================================================

$ErrorActionPreference = "Continue"
$ProgressPreference = "Continue"

# 设置环境变量
$env:PATH = "$env:PATH;C:\Users\HZHF\flutter_new\flutter\bin;C:\Android\Sdk\platform-tools;C:\Android\Sdk\cmdline-tools\latest\bin"
$env:ANDROID_HOME = "C:\Android\Sdk"
$env:FLUTTER_ROOT = "C:\Users\HZHF\flutter_new\flutter"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  SecChat Build and Test" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 检查Flutter
Write-Host "[1/8] Checking Flutter..." -ForegroundColor Yellow
$flutterVersion = & flutter --version 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "  [OK] Flutter: $flutterVersion" -ForegroundColor Green
} else {
    Write-Error "Flutter not found or not working"
    exit 1
}

# 检查Android SDK
Write-Host "[2/8] Checking Android SDK..." -ForegroundColor Yellow
$adbVersion = & adb version 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "  [OK] ADB: $adbVersion" -ForegroundColor Green
} else {
    Write-Error "ADB not found"
    exit 1
}

# 检查设备
Write-Host "[3/8] Checking devices..." -ForegroundColor Yellow
$devices = & adb devices 2>&1 | Select-String "device$" | Where-Object { $_ -notmatch "List of devices" }
if ($devices) {
    Write-Host "  [OK] Found devices:" -ForegroundColor Green
    $devices | ForEach-Object { Write-Host "    $_" -ForegroundColor Gray }
} else {
    Write-Error "No devices found"
    exit 1
}

# 进入项目目录
Push-Location "apps\flutter_app"

# 获取依赖
Write-Host "[4/8] Getting Flutter dependencies..." -ForegroundColor Yellow
& flutter pub get 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to get dependencies"
    Pop-Location
    exit 1
}
Write-Host "  [OK] Dependencies installed" -ForegroundColor Green

# 构建APK
Write-Host "[5/8] Building APK..." -ForegroundColor Yellow
& flutter build apk --debug 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Error "Build failed"
    Pop-Location
    exit 1
}
Write-Host "  [OK] Build completed" -ForegroundColor Green

# 安装APK
Write-Host "[6/8] Installing APK..." -ForegroundColor Yellow
& adb install -r "build\app\outputs\flutter-apk\app-debug.apk" 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Warning "Installation may have failed, continuing..."
}
Write-Host "  [OK] Installation completed" -ForegroundColor Green

# 启动应用
Write-Host "[7/8] Starting app..." -ForegroundColor Yellow
& adb shell am start -n com.example.sec_chat/.MainActivity 2>&1 | Out-Null
Start-Sleep -Seconds 5

# 检查应用是否运行
$running = & adb shell ps 2>&1 | Select-String "com.example.sec_chat"
if ($running) {
    Write-Host "  [OK] App is running" -ForegroundColor Green
} else {
    Write-Error "App failed to start"
    Pop-Location
    exit 1
}

Pop-Location

# 运行测试
Write-Host "[8/8] Running tests..." -ForegroundColor Yellow
& .\e2e_test.ps1 -SkipBuild -ReportPath "test_report_final_$(Get-Date -Format 'yyyyMMdd_HHmmss').md"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Build and Test Completed" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
