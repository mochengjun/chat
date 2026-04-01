# Start Docker Desktop and Wait
Write-Host "Starting Docker Desktop..."

$dockerPath = "C:\Program Files\Docker\Docker\Docker Desktop.exe"
if (Test-Path $dockerPath) {
    Start-Process -FilePath $dockerPath
    Write-Host "Docker Desktop process started"
} else {
    Write-Host "Docker Desktop not found at: $dockerPath"
    exit 1
}

# Wait for Docker daemon
Write-Host "Waiting for Docker daemon to be ready..."
$maxWait = 180
$waited = 0

while ($waited -lt $maxWait) {
    try {
        $result = docker info 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host ""
            Write-Host "Docker is ready!"
            Write-Host ""
            docker version
            exit 0
        }
    } catch {}
    
    Start-Sleep -Seconds 5
    $waited += 5
    
    if ($waited % 15 -eq 0) {
        Write-Host "Still waiting... ($waited seconds)"
    }
}

Write-Host ""
Write-Host "Docker failed to start within $maxWait seconds"
Write-Host "Last error:"
docker info 2>&1
exit 1
