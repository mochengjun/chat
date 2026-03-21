# Dart SDK Installation Script
# This script automatically downloads and installs Dart SDK

param(
    [string]$InstallPath = "C:\tools\dart-sdk",
    [string]$Version = "latest"
)

$ErrorActionPreference = "Stop"

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "       Dart SDK Installation Script" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

# Check if already installed
$dartExe = Join-Path $InstallPath "bin\dart.exe"
if (Test-Path $dartExe) {
    Write-Host "[INFO] Dart SDK already installed at: $InstallPath" -ForegroundColor Yellow
    $currentVersion = & $dartExe --version 2>&1
    Write-Host "[INFO] Current version: $currentVersion" -ForegroundColor Yellow
    $reinstall = Read-Host "Reinstall? (y/N)"
    if ($reinstall -ne "y" -and $reinstall -ne "Y") {
        Write-Host "[SKIP] Keeping existing installation" -ForegroundColor Green
        exit 0
    }
}

# Create installation directory
$installDir = Split-Path $InstallPath -Parent
if (-not (Test-Path $installDir)) {
    Write-Host "[STEP] Creating installation directory: $installDir" -ForegroundColor Green
    New-Item -ItemType Directory -Path $installDir -Force | Out-Null
}

# Download Dart SDK
$zipFile = "C:\Users\HZHF\Downloads\dart-sdk-windows-x64.zip"
$downloadUrl = "https://storage.googleapis.com/dart-archive/channels/stable/release/latest/sdk/dart-sdk-windows-x64.zip"

# Check if local zip file exists
if (Test-Path $zipFile) {
    Write-Host "[INFO] Found local Dart SDK archive: $zipFile" -ForegroundColor Green
} else {
    Write-Host "[STEP] Downloading Dart SDK..." -ForegroundColor Green
    Write-Host "        Download URL: $downloadUrl" -ForegroundColor Gray
    try {
        # Use .NET WebClient for download
        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadFile($downloadUrl, $zipFile)
        Write-Host "[SUCCESS] Download complete" -ForegroundColor Green
    } catch {
        Write-Host "[ERROR] Download failed: $_" -ForegroundColor Red
        Write-Host "[TIP] Please download Dart SDK manually to: $zipFile" -ForegroundColor Yellow
        exit 1
    }
}

# Extract and install
Write-Host "[STEP] Extracting Dart SDK..." -ForegroundColor Green
$tempExtractPath = Join-Path $env:TEMP "dart-sdk-extract"

try {
    # Remove temp directory
    if (Test-Path $tempExtractPath) {
        Remove-Item $tempExtractPath -Recurse -Force
    }
    
    # Extract to temp directory
    Expand-Archive -Path $zipFile -DestinationPath $tempExtractPath -Force
    
    # Find extracted dart-sdk directory
    $extractedSdkPath = Join-Path $tempExtractPath "dart-sdk"
    if (-not (Test-Path $extractedSdkPath)) {
        # Might be extracted directly to root
        $extractedSdkPath = $tempExtractPath
    }
    
    # Remove old installation directory
    if (Test-Path $InstallPath) {
        Remove-Item $InstallPath -Recurse -Force
    }
    
    # Move to final location
    Move-Item $extractedSdkPath $InstallPath -Force
    Write-Host "[SUCCESS] Extraction complete: $InstallPath" -ForegroundColor Green
    
    # Clean up temp directory
    if (Test-Path $tempExtractPath) {
        Remove-Item $tempExtractPath -Recurse -Force -ErrorAction SilentlyContinue
    }
} catch {
    Write-Host "[ERROR] Extraction failed: $_" -ForegroundColor Red
    exit 1
}

# Verify installation
Write-Host "[STEP] Verifying installation..." -ForegroundColor Green
if (Test-Path $dartExe) {
    $version = & $dartExe --version 2>&1
    Write-Host "[SUCCESS] Dart SDK installed successfully!" -ForegroundColor Green
    Write-Host "        Version: $version" -ForegroundColor Cyan
    
    # Test pub command availability
    $pubHelp = & "$InstallPath\bin\dart.exe" pub --help 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "        Pub tool is available" -ForegroundColor Cyan
    }
} else {
    Write-Host "[ERROR] Installation verification failed, dart.exe not found" -ForegroundColor Red
    exit 1
}

# Environment variable configuration guide
Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "       Environment Variable Configuration" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Manual configuration required (admin privileges needed):" -ForegroundColor Yellow
Write-Host ""
Write-Host "Method 1: Via System Settings" -ForegroundColor White
Write-Host "  1. Press Win + R, type sysdm.cpl to open System Properties" -ForegroundColor Gray
Write-Host "  2. Click Advanced tab -> Environment Variables" -ForegroundColor Gray
Write-Host "  3. Find Path in System variables, click Edit" -ForegroundColor Gray
Write-Host "  4. Add: $InstallPath\bin" -ForegroundColor Cyan
Write-Host "  5. Create new system variable DART_SDK_PATH with value: $InstallPath" -ForegroundColor Cyan
Write-Host ""
Write-Host "Method 2: Using PowerShell (requires admin privileges)" -ForegroundColor White
Write-Host "  Run the following commands:" -ForegroundColor Gray
Write-Host ""
Write-Host "  # Add to PATH" -ForegroundColor DarkGray
Write-Host "  [Environment]::SetEnvironmentVariable('PATH', `$env:PATH + ';$InstallPath\bin', 'Machine')" -ForegroundColor Yellow
Write-Host ""
Write-Host "  # Set DART_SDK_PATH" -ForegroundColor DarkGray
Write-Host "  [Environment]::SetEnvironmentVariable('DART_SDK_PATH', '$InstallPath', 'Machine')" -ForegroundColor Yellow
Write-Host ""
Write-Host "After configuration, reopen terminal for changes to take effect." -ForegroundColor Green
Write-Host ""
Write-Host "Verification commands:" -ForegroundColor White
Write-Host "  dart --version" -ForegroundColor Cyan
Write-Host "  dart pub --version" -ForegroundColor Cyan
Write-Host ""

# Try automatic configuration (requires admin privileges)
$autoConfig = Read-Host "Try automatic environment variable configuration? Requires admin privileges (y/N)"
if ($autoConfig -eq "y" -or $autoConfig -eq "Y") {
    try {
        # Check if running as admin
        $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
        $isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        
        if (-not $isAdmin) {
            Write-Host "[WARN] Not running as admin, attempting to restart with admin privileges..." -ForegroundColor Yellow
            Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" -InstallPath `"$InstallPath`"" -Verb RunAs
            exit 0
        }
        
        # Get current PATH
        $currentPath = [Environment]::GetEnvironmentVariable("PATH", "Machine")
        $dartBinPath = "$InstallPath\bin"
        
        # Check if already in PATH
        if ($currentPath -notlike "*$dartBinPath*") {
            $newPath = $currentPath + ";" + $dartBinPath
            [Environment]::SetEnvironmentVariable("PATH", $newPath, "Machine")
            Write-Host "[SUCCESS] Added Dart SDK to system PATH" -ForegroundColor Green
        } else {
            Write-Host "[INFO] Dart SDK already in PATH" -ForegroundColor Yellow
        }
        
        # Set DART_SDK_PATH
        [Environment]::SetEnvironmentVariable("DART_SDK_PATH", $InstallPath, "Machine")
        Write-Host "[SUCCESS] Set DART_SDK_PATH environment variable" -ForegroundColor Green
        
        Write-Host ""
        Write-Host "[IMPORTANT] Close current terminal and reopen for environment variables to take effect" -ForegroundColor Cyan
        
    } catch {
        Write-Host "[ERROR] Automatic configuration failed: $_" -ForegroundColor Red
        Write-Host "[TIP] Please follow the manual configuration guide above" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "       Installation Complete!" -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "Installation path: $InstallPath" -ForegroundColor White
Write-Host "Executable: $InstallPath\bin\dart.exe" -ForegroundColor White
Write-Host "Pub tool: $InstallPath\bin\dart.exe pub" -ForegroundColor White
Write-Host ""
