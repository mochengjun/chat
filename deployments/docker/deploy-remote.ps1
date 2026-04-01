# Docker初始化和项目部署脚本
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Windows服务器部署脚本" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

# 1. 启动Docker Desktop
Write-Host "启动Docker Desktop..." -ForegroundColor Yellow
$dockerPath = "C:\Program Files\Docker\Docker\Docker Desktop.exe"
if (Test-Path $dockerPath) {
    Start-Process $dockerPath
    Write-Host "Docker Desktop已启动" -ForegroundColor Green
} else {
    Write-Host "Docker Desktop未安装，请先安装" -ForegroundColor Red
    exit 1
}

# 2. 等待Docker就绪
Write-Host "等待Docker就绪..." -ForegroundColor Yellow
$maxWait = 120
$waited = 0
while ($waited -lt $maxWait) {
    try {
        $result = docker info 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Docker已就绪" -ForegroundColor Green
            docker --version
            break
        }
    } catch {}
    Start-Sleep -Seconds 5
    $waited += 5
    Write-Host "等待中... ($waited 秒)"
}

# 3. 创建项目目录
Write-Host "`n创建项目目录..." -ForegroundColor Yellow
$projectPath = "C:\chat"
New-Item -Path $projectPath -ItemType Directory -Force | Out-Null
Write-Host "项目目录: $projectPath" -ForegroundColor Green

# 4. 创建docker-compose.yml
Write-Host "`n创建Docker配置..." -ForegroundColor Yellow
$composeContent = @'
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
'@
Set-Content -Path "$projectPath\docker-compose.yml" -Value $composeContent -Encoding UTF8
Write-Host "已创建 docker-compose.yml" -ForegroundColor Green

# 5. 创建nginx配置
$nginxContent = @'
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
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        }

        location /api/v1/ws {
            proxy_pass http://auth_service/;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_set_header Host $host;
            proxy_read_timeout 3600s;
        }

        location / {
            proxy_pass http://auth_service/;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
        }
    }
}
'@
Set-Content -Path "$projectPath\nginx.conf" -Value $nginxContent -Encoding UTF8
Write-Host "已创建 nginx.conf" -ForegroundColor Green

# 6. 启动服务
Write-Host "`n启动Docker服务..." -ForegroundColor Yellow
Set-Location $projectPath
docker compose up -d

# 7. 等待服务启动
Write-Host "`n等待服务启动..." -ForegroundColor Yellow
Start-Sleep -Seconds 15

# 8. 显示状态
Write-Host "`n服务状态:" -ForegroundColor Yellow
docker compose ps

Write-Host "`n==========================================" -ForegroundColor Cyan
Write-Host "部署完成!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "`n访问地址:" -ForegroundColor White
Write-Host "  HTTP:  http://8.130.55.126" -ForegroundColor Cyan
Write-Host "  API:   http://8.130.55.126:8081" -ForegroundColor Cyan
Write-Host "  健康检查: http://8.130.55.126/health" -ForegroundColor Cyan
