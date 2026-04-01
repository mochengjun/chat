# Windows服务器部署脚本
# 服务器IP: 8.130.55.126
# 使用方式: 在服务器上以管理员权限运行

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Windows服务器部署脚本" -ForegroundColor Cyan
Write-Host "服务器IP: 8.130.55.126" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# 1. 检查并安装Docker Desktop
Write-Host "=== 1. 检查Docker环境 ===" -ForegroundColor Yellow

$dockerInstalled = Get-Command docker -ErrorAction SilentlyContinue
if ($dockerInstalled) {
    Write-Host "Docker已安装:" -ForegroundColor Green
    docker --version
} else {
    Write-Host "正在安装Docker Desktop..." -ForegroundColor Yellow

    # 下载Docker Desktop安装程序
    $dockerUrl = "https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe"
    $installerPath = "$env:TEMP\DockerDesktopInstaller.exe"

    Write-Host "下载Docker Desktop..."
    Invoke-WebRequest -Uri $dockerUrl -OutFile $installerPath -UseBasicParsing

    Write-Host "安装Docker Desktop (这可能需要几分钟)..."
    Start-Process -FilePath $installerPath -ArgumentList "install", "--quiet", "--accept-license" -Wait

    Write-Host "Docker Desktop安装完成" -ForegroundColor Green
    Write-Host "请注意: 可能需要重启服务器并重新运行此脚本" -ForegroundColor Yellow
}

# 2. 开放防火墙端口
Write-Host ""
Write-Host "=== 2. 配置防火墙端口 ===" -ForegroundColor Yellow

$ports = @(
    @{Name='HTTP'; Port=80},
    @{Name='HTTPS'; Port=443},
    @{Name='API'; Port=8081}
)

foreach ($p in $ports) {
    $rule = Get-NetFirewallRule -Name $p.Name -ErrorAction SilentlyContinue
    if (-not $rule) {
        New-NetFirewallRule -Name $p.Name -DisplayName $p.Name -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort $p.Port
        Write-Host "已开放端口: $($p.Port) ($($p.Name))" -ForegroundColor Green
    } else {
        Write-Host "端口 $($p.Port) ($($p.Name)) 已存在" -ForegroundColor Green
    }
}

# 3. 创建项目目录
Write-Host ""
Write-Host "=== 3. 创建项目目录 ===" -ForegroundColor Yellow

$projectPath = "C:\chat"
if (-not (Test-Path $projectPath)) {
    New-Item -Path $projectPath -ItemType Directory -Force
    Write-Host "已创建目录: $projectPath" -ForegroundColor Green
}

# 4. 创建docker-compose.yml
Write-Host ""
Write-Host "=== 4. 创建Docker配置 ===" -ForegroundColor Yellow

$composePath = "$projectPath\docker-compose.yml"
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
    image: golang:1.22-alpine
    container_name: sec-chat-api
    restart: unless-stopped
    working_dir: /app
    environment:
      - SERVER_PORT=8081
      - DATABASE_HOST=postgres
      - DATABASE_PORT=5432
      - DATABASE_NAME=sec_chat
      - DATABASE_USER=sec_chat
      - DATABASE_PASSWORD=SecurePassword123!
      - REDIS_HOST=redis
      - REDIS_PORT=6379
      - REDIS_PASSWORD=SecureRedis123!
      - JWT_SECRET=your-secure-jwt-secret-at-least-32-characters-long
      - ALLOWED_ORIGINS=http://8.130.55.126,http://8.130.55.126:80,http://8.130.55.126:8081
    ports:
      - "8081:8081"
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    command: ["sh", "-c", "sleep 5 && echo 'Service ready'"]

volumes:
  postgres_data:
  redis_data:
'@

Set-Content -Path $composePath -Value $composeContent -Encoding UTF8
Write-Host "已创建: $composePath" -ForegroundColor Green

# 5. 创建nginx配置
$nginxPath = "$projectPath\nginx.conf"
$nginxContent = @'
events {
    worker_connections 1024;
}

http {
    upstream auth_service {
        server auth-service:8081;
    }

    server {
        listen 80;
        server_name _;

        location /health {
            proxy_pass http://auth_service/health;
            proxy_http_version 1.1;
            proxy_set_header Connection "";
        }

        location /api/ {
            proxy_pass http://auth_service;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        }

        location /api/v1/ws {
            proxy_pass http://auth_service;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_set_header Host $host;
            proxy_read_timeout 3600s;
        }

        location / {
            proxy_pass http://auth_service;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
        }
    }
}
'@

Set-Content -Path $nginxPath -Value $nginxContent -Encoding UTF8
Write-Host "已创建: $nginxPath" -ForegroundColor Green

# 6. 启动服务
Write-Host ""
Write-Host "=== 5. 启动Docker服务 ===" -ForegroundColor Yellow

# 检查Docker服务是否运行
$dockerService = Get-Service -Name "com.docker.service" -ErrorAction SilentlyContinue
if (-not $dockerService) {
    Write-Host "启动Docker Desktop..." -ForegroundColor Yellow
    Start-Process "C:\Program Files\Docker\Docker\Docker Desktop.exe"
    Start-Sleep -Seconds 30
}

# 等待Docker就绪
Write-Host "等待Docker就绪..."
$maxWait = 60
$waited = 0
while ($waited -lt $maxWait) {
    try {
        docker info | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Docker已就绪" -ForegroundColor Green
            break
        }
    } catch {}
    Start-Sleep -Seconds 5
    $waited += 5
    Write-Host "等待中... ($waited秒)"
}

# 启动容器
Set-Location $projectPath
Write-Host "启动容器服务..."
docker compose up -d

# 7. 验证服务
Write-Host ""
Write-Host "=== 6. 验证服务状态 ===" -ForegroundColor Yellow

Start-Sleep -Seconds 10

Write-Host ""
docker compose ps

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "部署完成!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "访问地址:" -ForegroundColor White
Write-Host "  HTTP:  http://8.130.55.126" -ForegroundColor Cyan
Write-Host "  API:   http://8.130.55.126:8081" -ForegroundColor Cyan
Write-Host "  健康检查: http://8.130.55.126/health" -ForegroundColor Cyan
Write-Host ""
Write-Host "管理命令:" -ForegroundColor White
Write-Host "  查看日志: docker compose logs" -ForegroundColor Gray
Write-Host "  重启服务: docker compose restart" -ForegroundColor Gray
Write-Host "  停止服务: docker compose down" -ForegroundColor Gray
