# Docker and Project Deployment Script
Write-Host "=========================================="
Write-Host "Windows Server Deployment Script"
Write-Host "=========================================="

# 1. Start Docker Desktop
Write-Host "Starting Docker Desktop..."
$dockerPath = "C:\Program Files\Docker\Docker\Docker Desktop.exe"
if (Test-Path $dockerPath) {
    Start-Process $dockerPath
    Write-Host "Docker Desktop started"
} else {
    Write-Host "Docker Desktop not installed"
    exit 1
}

# 2. Wait for Docker to be ready
Write-Host "Waiting for Docker..."
$maxWait = 120
$waited = 0
while ($waited -lt $maxWait) {
    try {
        $result = docker info 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Docker is ready"
            docker --version
            break
        }
    } catch {}
    Start-Sleep -Seconds 5
    $waited += 5
    Write-Host "Waiting... ($waited seconds)"
}

# 3. Create project directory
Write-Host ""
Write-Host "Creating project directory..."
$projectPath = "C:\chat"
New-Item -Path $projectPath -ItemType Directory -Force | Out-Null
Write-Host "Project directory: $projectPath"

# 4. Create docker-compose.yml
Write-Host ""
Write-Host "Creating Docker configuration..."
$composeContent = @"
version: '3.8'

services:
  postgres:
    image: postgres:16-alpine
    container_name: sec-chat-postgres
    restart: unless-stopped
    environment:
      POSTGRES_DB: sec_chat
      POSTGRES_USER: sec_chat
      POSTGRES_PASSWORD: SecurePassword123!
    volumes:
      - postgres_data:/var/lib/postgresql/data
    ports:
      - "5432:5432"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U sec_chat"]
      interval: 10s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    container_name: sec-chat-redis
    restart: unless-stopped
    command: redis-server --requirepass SecureRedis123!
    volumes:
      - redis_data:/data
    ports:
      - "6379:6379"
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5

  nginx:
    image: nginx:1.25-alpine
    container_name: sec-chat-nginx
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
    depends_on:
      - auth-service

  auth-service:
    image: nginx:1.25-alpine
    container_name: sec-chat-api
    restart: unless-stopped
    ports:
      - "8081:80"
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy

volumes:
  postgres_data:
  redis_data:
"@
Set-Content -Path "$projectPath\docker-compose.yml" -Value $composeContent -Encoding UTF8
Write-Host "Created docker-compose.yml"

# 5. Create nginx config
$nginxContent = @"
events {
    worker_connections 1024;
}

http {
    upstream auth_service {
        server auth-service:80;
    }

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

        location /api/ {
            proxy_pass http://auth_service/;
            proxy_set_header Host `$host;
            proxy_set_header X-Real-IP `$remote_addr;
            proxy_set_header X-Forwarded-For `$proxy_add_x_forwarded_for;
        }

        location /api/v1/ws {
            proxy_pass http://auth_service/;
            proxy_http_version 1.1;
            proxy_set_header Upgrade `$http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_set_header Host `$host;
            proxy_read_timeout 3600s;
        }

        location / {
            proxy_pass http://auth_service/;
            proxy_set_header Host `$host;
            proxy_set_header X-Real-IP `$remote_addr;
        }
    }
}
"@
Set-Content -Path "$projectPath\nginx.conf" -Value $nginxContent -Encoding UTF8
Write-Host "Created nginx.conf"

# 6. Start services
Write-Host ""
Write-Host "Starting Docker services..."
Set-Location $projectPath
docker compose up -d

# 7. Wait for services
Write-Host ""
Write-Host "Waiting for services to start..."
Start-Sleep -Seconds 15

# 8. Show status
Write-Host ""
Write-Host "Service status:"
docker compose ps

Write-Host ""
Write-Host "=========================================="
Write-Host "Deployment completed!"
Write-Host "=========================================="
Write-Host ""
Write-Host "Access URLs:"
Write-Host "  HTTP:  http://8.130.55.126"
Write-Host "  API:   http://8.130.55.126:8081"
Write-Host "  Health: http://8.130.55.126/health"
