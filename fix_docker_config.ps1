# Docker配置文件修复脚本
# 解决daemon.json JSON语法错误问题

Write-Host "=== Docker配置文件修复工具 ===" -ForegroundColor Green

# 定义配置文件路径
$configPaths = @(
    "$env:APPDATA\Docker\config\daemon.json",
    "$env:ProgramData\docker\config\daemon.json"
)

Write-Host "`n检查配置文件..." -ForegroundColor Yellow

$foundValidConfig = $false

foreach ($configPath in $configPaths) {
    Write-Host "`n检查: $configPath" -ForegroundColor Cyan
    
    if (Test-Path $configPath) {
        Write-Host "✓ 文件存在" -ForegroundColor Green
        
        try {
            $content = Get-Content $configPath -Raw
            Write-Host "文件内容：" -ForegroundColor Yellow
            Write-Host $content
            
            # 尝试解析JSON
            $json = $content | ConvertFrom-Json
            Write-Host "✓ JSON语法有效" -ForegroundColor Green
            $foundValidConfig = $true
            
        } catch {
            Write-Host "✗ JSON语法错误: $($_.Exception.Message)" -ForegroundColor Red
            
            # 创建备份
            $backupPath = "$configPath.backup.$(Get-Date -Format 'yyyyMMdd_HHmmss')"
            Copy-Item $configPath $backupPath -Force
            Write-Host "已备份到: $backupPath" -ForegroundColor Yellow
            
            # 删除损坏的配置文件
            Remove-Item $configPath -Force
            Write-Host "已删除损坏的配置文件" -ForegroundColor Green
        }
    } else {
        Write-Host "文件不存在" -ForegroundColor Gray
    }
}

# 如果没有找到有效的配置文件，创建一个新的
if (-not $foundValidConfig) {
    Write-Host "`n创建新的配置文件..." -ForegroundColor Yellow
    
    $newConfig = @{
        "registry-mirrors" = @(
            "https://docker.mirrors.ustc.edu.cn",
            "https://hub-mirror.c.163.com"
        )
        "experimental" = $false
        "debug" = $false
    }
    
    # 选择首选路径
    $targetPath = $configPaths[0]  # APPDATA路径
    
    # 确保目录存在
    $configDir = Split-Path $targetPath
    if (!(Test-Path $configDir)) {
        New-Item -ItemType Directory -Path $configDir -Force
    }
    
    # 保存新配置
    $newConfig | ConvertTo-Json -Depth 4 | Out-File -FilePath $targetPath -Encoding UTF8
    Write-Host "✓ 已创建新的配置文件: $targetPath" -ForegroundColor Green
}

Write-Host "`n=== 修复完成 ===" -ForegroundColor Green
Write-Host "建议操作：" -ForegroundColor Cyan
Write-Host "1. 重启Docker Desktop" -ForegroundColor White
Write-Host "2. 如果仍有问题，可以尝试重置到出厂设置" -ForegroundColor White