# Go环境安装脚本
$goVersion = "1.23.0"
$goUrl = "https://go.dev/dl/go$goVersion.windows-amd64.zip"
$output = "$env:TEMP\go.zip"
$installDir = "C:\Go"

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "   Go $goVersion Installation Script" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

# Check if Go is already installed
$existingGo = Get-Command go -ErrorAction SilentlyContinue
if ($existingGo) {
    $currentVersion = go version
    Write-Host "[INFO] Go is already installed: $currentVersion" -ForegroundColor Yellow
    Write-Host "       Skipping installation." -ForegroundColor Yellow
    exit 0
}

# Download Go
Write-Host "[STEP 1/3] Downloading Go $goVersion..." -ForegroundColor Yellow
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri $goUrl -OutFile $output -UseBasicParsing
    Write-Host "  [OK] Download completed: $output" -ForegroundColor Green
} catch {
    Write-Host "  [ERROR] Download failed: $_" -ForegroundColor Red
    # Try alternative mirror
    $goUrl = "https://dl.google.com/go/go$goVersion.windows-amd64.zip"
    Write-Host "  [INFO] Trying alternative mirror..." -ForegroundColor Yellow
    try {
        Invoke-WebRequest -Uri $goUrl -OutFile $output -UseBasicParsing
        Write-Host "  [OK] Download completed from alternative mirror" -ForegroundColor Green
    } catch {
        Write-Host "  [ERROR] Alternative download also failed: $_" -ForegroundColor Red
        exit 1
    }
}

# Extract Go
Write-Host ""
Write-Host "[STEP 2/3] Extracting Go..." -ForegroundColor Yellow
try {
    if (Test-Path $installDir) {
        Remove-Item -Path $installDir -Recurse -Force
    }
    Expand-Archive -Path $output -DestinationPath "C:\" -Force
    Write-Host "  [OK] Extraction completed" -ForegroundColor Green
} catch {
    Write-Host "  [ERROR] Extraction failed: $_" -ForegroundColor Red
    exit 1
}

# Configure environment
Write-Host ""
Write-Host "[STEP 3/3] Configuring environment..." -ForegroundColor Yellow

# Set environment variables for current session
$env:Path = "$installDir\bin;$env:Path"
$env:GOPATH = "$env:USERPROFILE\go"
$env:GOPROXY = "https://goproxy.cn,https://goproxy.io,direct"

# Set permanent environment variables
[Environment]::SetEnvironmentVariable("Path", "$installDir\bin;" + [Environment]::GetEnvironmentVariable("Path", "Machine"), "Machine")
[Environment]::SetEnvironmentVariable("GOPATH", "$env:USERPROFILE\go", "Machine")
[Environment]::SetEnvironmentVariable("GOPROXY", "https://goproxy.cn,https://goproxy.io,direct", "Machine")

Write-Host "  [OK] Environment configured" -ForegroundColor Green

# Verify installation
Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "   Go Installation Complete" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

# Refresh environment and test
$env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")

# Test Go
try {
    $goExe = Join-Path $installDir "bin\go.exe"
    $version = & $goExe version
    Write-Host "Go Version: $version" -ForegroundColor Green
    Write-Host "GOPATH: $env:GOPATH" -ForegroundColor Green
    Write-Host "GOPROXY: $env:GOPROXY" -ForegroundColor Green
} catch {
    Write-Host "[WARNING] Could not verify Go installation: $_" -ForegroundColor Yellow
}

# Cleanup
Remove-Item -Path $output -Force -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "[INFO] Please restart your terminal to apply environment changes." -ForegroundColor Yellow
Write-Host ""
