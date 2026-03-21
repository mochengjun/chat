# 企业安全聊天系统 - 网络配置修复 (PowerShell 版本)
# 自动请求管理员权限并执行修复操作

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  企业安全聊天系统网络配置修复" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host

# 检查管理员权限
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "✗ 需要管理员权限执行此脚本" -ForegroundColor Red
    Write-Host
    Write-Host "正在重新启动为管理员模式..." -ForegroundColor Yellow
    
    # 重启为管理员
    Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    exit
}

Write-Host "✓ 管理员权限验证通过" -ForegroundColor Green
Write-Host

try {
    # 切换到脚本所在目录
    $scriptDir = Split-Path -Parent $PSCommandPath
    Set-Location $scriptDir
    
    # 执行 bat 文件
    Write-Host "[1/4] 修复 ZeroTier 服务配置..." -ForegroundColor Cyan
    & ".\fix_network_config.bat"
    
} catch {
    Write-Host "✗ 执行失败: $_" -ForegroundColor Red
    Write-Host "按任意键退出..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}
