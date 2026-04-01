# Start Docker and Deploy
Write-Host "Starting Docker Desktop..."

$dockerPath = "C:\Program Files\Docker\Docker\Docker Desktop.exe"
if (Test-Path $dockerPath) {
    Start-Process $dockerPath
    Write-Host "Docker Desktop started"
} else {
    Write-Host "Docker Desktop not found"
    exit 1
}

# Wait for Docker to be ready
Write-Host "Waiting for Docker to be ready (this may take 1-2 minutes)..."
$maxWait = 120
$waited = 0
$ready = $false

while ($waited -lt $maxWait) {
    try {
        $info = docker info 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Docker is ready!"
            docker --version
            $ready = $true
            break
        }
    } catch {}
    
    Start-Sleep -Seconds 5
    $waited += 5
    Write-Host "Waiting... ($waited seconds)"
}

if (-not $ready) {
    Write-Host "Docker failed to start within timeout"
    exit 1
}

# Create project directory
Write-Host ""
Write-Host "Creating project directory..."
$projectPath = "C:\chat"
New-Item -Path $projectPath -ItemType Directory -Force | Out-Null

# Create docker-compose.yml
Write-Host "Creating docker-compose.yml..."
$composeContent = @"
version: '3.8'
services:
  nginx:
    image: nginx:1.25-alpine
    container_name: sec-chat-nginx
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro

  api:
    image: nginx:1.25-alpine
    container_name: sec-chat-api
    restart: unless-stopped
    ports:
      - "8081:80"
"@

$composeContent | Out-File -FilePath "$projectPath\docker-compose.yml" -Encoding utf8

# Create nginx.conf
Write-Host "Creating nginx.conf..."
$nginxContent = @"
events {
    worker_connections 1024;
}
http {
    server {
        listen 80;
        server_name _;
        
        location /health {
            return 200 "healthy`n";
            add_header Content-Type text/plain;
        }
        
        location /nginx-health {
            return 200 "healthy`n";
            add_header Content-Type text/plain;
        }
        
        location / {
            return 200 "Welcome to Secure Chat`n";
            add_header Content-Type text/plain;
        }
    }
}
"@

$nginxContent | Out-File -FilePath "$projectPath\nginx.conf" -Encoding utf8

# Start services
Write-Host ""
Write-Host "Starting services..."
Set-Location $projectPath
docker compose up -d

# Wait and show status
Start-Sleep -Seconds 10
Write-Host ""
Write-Host "Service status:"
docker compose ps

# Test endpoints
Write-Host ""
Write-Host "Testing endpoints..."
try {
    $response = Invoke-WebRequest -Uri "http://localhost/health" -TimeoutSec 5 -UseBasicParsing
    Write-Host "Port 80: OK (Status $($response.StatusCode))"
} catch {
    Write-Host "Port 80: Error - $_"
}

try {
    $response = Invoke-WebRequest -Uri "http://localhost:8081/" -TimeoutSec 5 -UseBasicParsing
    Write-Host "Port 8081: OK (Status $($response.StatusCode))"
} catch {
    Write-Host "Port 8081: Error - $_"
}

Write-Host ""
Write-Host "=========================================="
Write-Host "Deployment completed!"
Write-Host "=========================================="
Write-Host ""
Write-Host "Access URLs:"
Write-Host "  http://8.130.55.126"
Write-Host "  http://8.130.55.126:8081"
Write-Host "  http://8.130.55.126/health"
