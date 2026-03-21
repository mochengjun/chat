# 生产环境部署计划

## 部署目标
将更新部署到位于 C:\chat\ 的生产环境

## 当前环境状态
- 生产环境路径: C:\chat\
- 当前无运行中的Docker容器
- 目录结构包含完整的项目文件

## 部署前准备工作

### 1. 备份现有环境
```powershell
# 备份当前生产环境
$date = Get-Date -Format "yyyyMMdd_HHmmss"
$backupDir = "C:\chat_backup_$date"
Copy-Item -Path "C:\chat\" -Destination $backupDir -Recurse -Force
Write-Host "备份完成: $backupDir"
```

### 2. 构建最新版本
```powershell
# 构建web-client
cd C:\Users\MCJ\source\quest\chat\web-client
npm run build

# 验证构建结果
if (Test-Path "dist") {
    Write-Host "构建成功"
} else {
    Write-Error "构建失败"
    exit 1
}
```

### 3. 准备部署文件
```powershell
# 同步必要文件到生产环境
$sourceFiles = @(
    "web-client\dist\*",
    "services\auth-service\*",
    "deployments\docker\*",
    "README.md"
)

foreach ($file in $sourceFiles) {
    $sourcePath = "C:\Users\MCJ\source\quest\chat\$file"
    $destPath = "C:\chat\$file"
    
    if (Test-Path $sourcePath) {
        Copy-Item -Path $sourcePath -Destination $destPath -Recurse -Force
        Write-Host "已复制: $file"
    }
}
```

## 部署步骤

### 步骤1: 停止现有服务（如果存在）
```powershell
docker-compose -f C:\chat\deployments\docker\docker-compose.yml down
```

### 步骤2: 备份数据库和重要数据
```powershell
# 备份SQLite数据库
Copy-Item -Path "C:\chat\auth.db*" -Destination "C:\chat_backup_$date\" -Force

# 备份上传文件
Copy-Item -Path "C:\chat\uploads" -Destination "C:\chat_backup_$date\uploads" -Recurse -Force
```

### 步骤3: 部署新版本
```powershell
# 构建Docker镜像
cd C:\chat\deployments\docker
docker-compose build --no-cache

# 启动服务
docker-compose up -d
```

### 步骤4: 验证部署
```powershell
# 检查容器状态
docker ps

# 检查服务健康状态
curl -f http://localhost:8081/health
curl -f http://localhost/

# 查看日志
docker logs sec-chat-api
docker logs sec-chat-nginx
```

## 回滚计划

如果部署出现问题：
```powershell
# 停止新服务
docker-compose down

# 恢复备份
Remove-Item -Path "C:\chat\" -Recurse -Force
Copy-Item -Path "$backupDir" -Destination "C:\chat\" -Recurse -Force

# 重启旧服务
cd C:\chat\deployments\docker
docker-compose up -d
```

## 注意事项
1. 严格保持现有目录结构和路径配置
2. 不会覆盖或影响当前正在运行的服务器实例（当前无运行实例）
3. 遵循标准部署流程，确保服务连续性和数据完整性
4. 部署后验证服务正常运行