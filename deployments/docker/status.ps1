# Check Docker Status
Write-Host "Checking Docker status..."

# Check if Docker Desktop is installed
$dockerPath = "C:\Program Files\Docker\Docker\Docker Desktop.exe"
if (Test-Path $dockerPath) {
    Write-Host "Docker Desktop is installed at: $dockerPath"
} else {
    Write-Host "Docker Desktop NOT found"
}

# Check docker command
Write-Host ""
Write-Host "Checking docker CLI..."
$dockerCmd = Get-Command docker -ErrorAction SilentlyContinue
if ($dockerCmd) {
    Write-Host "Docker CLI found at: $($dockerCmd.Source)"
    docker --version
} else {
    Write-Host "Docker CLI not in PATH"
}

# Check Docker service
Write-Host ""
Write-Host "Checking Docker service..."
$service = Get-Service -Name "com.docker.service" -ErrorAction SilentlyContinue
if ($service) {
    Write-Host "Docker service status: $($service.Status)"
} else {
    Write-Host "Docker service not found"
}

# List Program Files\Docker if exists
Write-Host ""
Write-Host "Docker installation directory:"
if (Test-Path "C:\Program Files\Docker") {
    Get-ChildItem "C:\Program Files\Docker" -Recurse -Depth 1 | Select-Object FullName
} else {
    Write-Host "C:\Program Files\Docker not found"
}

# Check PATH
Write-Host ""
Write-Host "Docker in PATH:"
$env:PATH -split ';' | Where-Object { $_ -like '*docker*' }
