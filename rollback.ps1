param(
    [Parameter(Mandatory=$true)]
    [string]$BackupDir,
    
    [Parameter(Mandatory=$true)]
    [string]$TargetDir
)

Write-Host "=== 执行回滚操作 ===" -ForegroundColor Red

# 验证参数
if (!(Test-Path $BackupDir)) {
    Write-Error "备份目录不存在: $BackupDir"
    exit 1
}

if (!(Test-Path $TargetDir)) {
    Write-Error "目标目录不存在: $TargetDir"
    exit 1
}

try {
    # 步骤1: 停止当前服务
    Write-Host "步骤1: 停止当前服务" -ForegroundColor Yellow
    $composeFile = "$TargetDir\deployments\docker\docker-compose.yml"
    if (Test-Path $composeFile) {
        Set-Location "$TargetDir\deployments\docker"
        docker-compose down
        Write-Host "✓ 服务已停止"
    }
    
    # 步骤2: 清理目标目录
    Write-Host "步骤2: 清理目标目录" -ForegroundColor Yellow
    Remove-Item -Path "$TargetDir\*" -Recurse -Force
    Write-Host "✓ 目标目录已清理"
    
    # 步骤3: 恢复备份
    Write-Host "步骤3: 恢复备份文件" -ForegroundColor Yellow
    Copy-Item -Path "$BackupDir\*" -Destination $TargetDir -Recurse -Force
    Write-Host "✓ 备份恢复完成"
    
    # 步骤4: 重启服务
    Write-Host "步骤4: 重启服务" -ForegroundColor Yellow
    Set-Location "$TargetDir\deployments\docker"
    docker-compose up -d
    Write-Host "✓ 服务已重启"
    
    # 步骤5: 验证回滚
    Write-Host "步骤5: 验证回滚结果" -ForegroundColor Yellow
    Start-Sleep -Seconds 5
    docker ps | Select-String "sec-chat"
    
    Write-Host "`n=== 回滚完成 ===" -ForegroundColor Green
    Write-Host "系统已恢复到备份状态"
    
} catch {
    Write-Error "回滚过程中发生错误: $_"
    exit 1
}