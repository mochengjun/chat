# 生产环境部署脚本
# 日期: 2026年3月3日

Write-Host "=== 安全生产环境部署开始 ===" -ForegroundColor Green

# 设置变量
$SOURCE_DIR = "C:\Users\MCJ\source\quest\chat"
$TARGET_DIR = "C:\chat"
$TIMESTAMP = Get-Date -Format "yyyyMMdd_HHmmss"
$BACKUP_DIR = "C:\chat_backup_$TIMESTAMP"

Write-Host "源目录: $SOURCE_DIR"
Write-Host "目标目录: $TARGET_DIR"
Write-Host "备份目录: $BACKUP_DIR"

# 步骤1: 验证构建状态
Write-Host "`n=== 步骤1: 验证构建状态 ===" -ForegroundColor Yellow
$distPath = "$SOURCE_DIR\web-client\dist"
if (Test-Path $distPath) {
    $distSize = (Get-ChildItem $distPath -Recurse | Measure-Object -Property Length -Sum).Sum / 1MB
    Write-Host "✓ web-client构建完成，大小: $([math]::Round($distSize, 2)) MB"
} else {
    Write-Error "✗ web-client构建未找到，请先运行 npm run build"
    exit 1
}

# 步骤2: 创建备份
Write-Host "`n=== 步骤2: 创建备份 ===" -ForegroundColor Yellow
try {
    New-Item -ItemType Directory -Path $BACKUP_DIR -Force | Out-Null
    Copy-Item -Path "$TARGET_DIR\*" -Destination $BACKUP_DIR -Recurse -Force
    Write-Host "✓ 备份完成: $BACKUP_DIR"
} catch {
    Write-Warning "⚠ 备份过程出现警告: $_"
}

# 步骤3: 停止现有服务
Write-Host "`n=== 步骤3: 停止现有服务 ===" -ForegroundColor Yellow
$composeFile = "$TARGET_DIR\deployments\docker\docker-compose.yml"
if (Test-Path $composeFile) {
    try {
        Set-Location "$TARGET_DIR\deployments\docker"
        docker-compose down
        Write-Host "✓ 服务已停止"
    } catch {
        Write-Host "ℹ 无运行中的服务需要停止"
    }
} else {
    Write-Host "ℹ 未找到docker-compose配置文件"
}

# 步骤4: 备份关键数据
Write-Host "`n=== 步骤4: 备份关键数据 ===" -ForegroundColor Yellow
$keyFiles = @("auth.db", "auth.db-shm", "auth.db-wal")
foreach ($file in $keyFiles) {
    $filePath = "$TARGET_DIR\$file"
    if (Test-Path $filePath) {
        Copy-Item -Path $filePath -Destination "$BACKUP_DIR\$file" -Force
        Write-Host "✓ 已备份: $file"
    }
}

# 步骤5: 部署新文件
Write-Host "`n=== 步骤5: 部署新文件 ===" -ForegroundColor Yellow
$deployFiles = @{
    "web-client\dist" = "web-client\dist"
    "services\auth-service" = "services\auth-service"
    "deployments\docker" = "deployments\docker"
    "README.md" = "README.md"
}

foreach ($source in $deployFiles.Keys) {
    $sourcePath = "$SOURCE_DIR\$source"
    $targetPath = "$TARGET_DIR\$($deployFiles[$source])"
    
    if (Test-Path $sourcePath) {
        # 创建目标目录
        $targetParent = Split-Path $targetPath -Parent
        if (!(Test-Path $targetParent)) {
            New-Item -ItemType Directory -Path $targetParent -Force | Out-Null
        }
        
        # 复制文件
        Copy-Item -Path $sourcePath -Destination $targetPath -Recurse -Force
        Write-Host "✓ 已部署: $source"
    } else {
        Write-Warning "⚠ 源文件不存在: $sourcePath"
    }
}

# 步骤6: 构建和启动服务
Write-Host "`n=== 步骤6: 构建和启动服务 ===" -ForegroundColor Yellow
try {
    Set-Location "$TARGET_DIR\deployments\docker"
    
    # 构建镜像
    Write-Host "正在构建Docker镜像..."
    docker-compose build --no-cache
    
    # 启动服务
    Write-Host "正在启动服务..."
    docker-compose up -d
    
    Write-Host "✓ 服务启动完成"
} catch {
    Write-Error "✗ 服务启动失败: $_"
    Write-Host "正在执行回滚..."
    & "$PSScriptRoot\rollback.ps1" $BACKUP_DIR $TARGET_DIR
    exit 1
}

# 步骤7: 验证部署
Write-Host "`n=== 步骤7: 验证部署 ===" -ForegroundColor Yellow
Start-Sleep -Seconds 10  # 等待服务启动

# 检查容器状态
Write-Host "检查容器状态:"
docker ps | Select-String "sec-chat"

# 检查服务健康
try {
    $apiHealth = Invoke-WebRequest -Uri "http://localhost:8081/health" -TimeoutSec 10 -ErrorAction Stop
    Write-Host "✓ API服务健康检查通过 (状态码: $($apiHealth.StatusCode))"
} catch {
    Write-Warning "⚠ API健康检查失败: $_"
}

try {
    $webHealth = Invoke-WebRequest -Uri "http://localhost/" -TimeoutSec 10 -ErrorAction Stop
    Write-Host "✓ Web服务健康检查通过 (状态码: $($webHealth.StatusCode))"
} catch {
    Write-Warning "⚠ Web健康检查失败: $_"
}

Write-Host "`n=== 部署完成 ===" -ForegroundColor Green
Write-Host "备份位置: $BACKUP_DIR"
Write-Host "如需回滚，请运行: .\rollback.ps1 $BACKUP_DIR $TARGET_DIR"