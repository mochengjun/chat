# Check Docker Status
Write-Host "Checking Docker status..."

# Check Docker command
try {
    $version = docker version 2>&1
    Write-Host "Docker version output:"
    Write-Host $version
} catch {
    Write-Host "Docker command failed: $_"
}

# Check Docker service
$service = Get-Service -Name "com.docker.service" -ErrorAction SilentlyContinue
if ($service) {
    Write-Host "Docker service: $($service.Status)"
}

# Check if WSL is working
Write-Host ""
Write-Host "WSL status:"
wsl --status 2>&1

# Check processes
Write-Host ""
Write-Host "Docker processes:"
Get-Process | Where-Object { $_.ProcessName -like "*docker*" } | Select-Object ProcessName, Id

# Show PATH
Write-Host ""
Write-Host "PATH contains Docker:"
$env:PATH -split ';' | Where-Object { $_ -like '*docker*' -or $_ -like '*Docker*' }
