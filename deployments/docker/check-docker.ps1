# Check Docker Installation
Write-Host "Checking Docker installation..."

if (Test-Path "C:\Program Files\Docker\Docker\Docker Desktop.exe") {
    Write-Host "Docker Desktop is installed"
    & "C:\Program Files\Docker\Docker\Docker Desktop.exe"
} else {
    Write-Host "Docker Desktop not found, installing..."
    
    # Enable WSL
    Write-Host "Enabling WSL..."
    dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
    dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
    
    # Download Docker Desktop
    Write-Host "Downloading Docker Desktop..."
    $url = "https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe"
    $path = "$env:TEMP\DockerDesktopInstaller.exe"
    
    try {
        Invoke-WebRequest -Uri $url -OutFile $path -UseBasicParsing
        Write-Host "Download completed: $path"
        
        # Install Docker Desktop
        Write-Host "Installing Docker Desktop (this takes several minutes)..."
        Start-Process -FilePath $path -ArgumentList "install", "--quiet", "--accept-license", "--no-windows-containers" -Wait
        Write-Host "Docker Desktop installation completed"
    } catch {
        Write-Host "Error downloading Docker: $_"
    }
}

# Check Docker command
Write-Host ""
Write-Host "Checking docker command..."
try {
    docker --version 2>$null
    Write-Host "Docker CLI is available"
} catch {
    Write-Host "Docker CLI not available in PATH"
}

# Show Program Files
Write-Host ""
Write-Host "Contents of Program Files:"
Get-ChildItem "C:\Program Files" | Select-Object Name
