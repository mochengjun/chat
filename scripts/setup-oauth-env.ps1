# ========================================
# OAuth 环境变量配置助手 (PowerShell)
# ========================================
# 此脚本帮助您快速配置 Google OAuth 环境变量
# 使用方法: .\setup-oauth-env.ps1

param()

# 颜色函数
function Write-ColorOutput($ForegroundColor) {
    $fc = $host.UI.RawUI.ForegroundColor
    $host.UI.RawUI.ForegroundColor = $ForegroundColor
    if ($args) {
        Write-Output $args
    }
    $host.UI.RawUI.ForegroundColor = $fc
}

# 项目路径
$projectRoot = Split-Path -Parent $PSScriptRoot
$authServiceDir = Join-Path $projectRoot "services\auth-service"
$envFile = Join-Path $authServiceDir ".env.local"

Write-ColorOutput Cyan "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
Write-ColorOutput Cyan "   Google OAuth 环境变量配置助手"
Write-ColorOutput Cyan "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
Write-Output ""

# 检查文件是否存在
if (Test-Path $envFile) {
    Write-ColorOutput Yellow "警告: .env.local 文件已存在"
    $overwrite = Read-Host "是否覆盖现有配置? (y/N)"
    if ($overwrite -ne 'y' -and $overwrite -ne 'Y') {
        Write-ColorOutput Yellow "操作已取消"
        exit
    }
    # 备份
    $backupFile = "$envFile.backup.$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    Copy-Item $envFile $backupFile
    Write-ColorOutput Green "✓ 已备份现有配置"
}

Write-Output ""
Write-ColorOutput Cyan "请输入您的 Google OAuth 凭据信息："
Write-ColorOutput Yellow "（可从 Google Cloud Console 获取）"
Write-Output ""

# 收集配置
$googleClientId = Read-Host "Google Client ID"
$googleClientSecret = Read-Host "Google Client Secret"

# 选择环境
Write-Output ""
Write-ColorOutput Cyan "选择部署环境："
Write-Output "1) 开发环境 (localhost)"
Write-Output "2) 生产环境"
$envChoice = Read-Host "请选择 (1/2)"

switch ($envChoice) {
    '1' {
        $googleRedirectUrl = "http://localhost:8081/api/v1/auth/oauth/google/callback"
        $forceHttps = "false"
        $cookieSecure = "false"
        $allowedOrigins = "http://localhost:3000,http://localhost:5173,http://localhost:8081"
    }
    '2' {
        $productionDomain = Read-Host "生产域名 (例如: chat.yourcompany.com)"
        $googleRedirectUrl = "https://$productionDomain/api/v1/auth/oauth/google/callback"
        $forceHttps = "true"
        $cookieSecure = "true"
        $allowedOrigins = "https://$productionDomain"
    }
    default {
        Write-ColorOutput Red "无效选择"
        exit 1
    }
}

# 可选配置
Write-Output ""
Write-ColorOutput Cyan "可选配置（按 Enter 使用默认值）："
$allowedDomains = Read-Host "允许的企业邮箱域名 (留空允许所有)"
$jwtSecretInput = Read-Host "JWT Secret (至少32字符) [自动生成]"

# 生成 JWT Secret
if ([string]::IsNullOrWhiteSpace($jwtSecretInput)) {
    # 生成随机 32 字节并转换为 Base64
    $bytes = New-Object byte[] 32
    [Security.Cryptography.RNGCryptoServiceProvider]::Create().GetBytes($bytes)
    $jwtSecret = [Convert]::ToBase64String($bytes)
    Write-ColorOutput Yellow "✓ 已生成随机 JWT Secret"
} else {
    $jwtSecret = $jwtSecretInput
}

# 验证 JWT Secret 长度
if ($jwtSecret.Length -lt 32) {
    Write-ColorOutput Red "错误: JWT Secret 必须至少 32 个字符"
    exit 1
}

# 默认值
$oauthStateExpiry = "300"
$oauthAutoCreateUser = "true"
$cookieSameSite = "Lax"

# 创建配置文件
Write-Output ""
Write-ColorOutput Cyan "正在创建 .env.local 文件..."

$envContent = @"
# ========================================
# Google OAuth 配置
# ========================================
# 生成时间: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
# 环境: $(if ($envChoice -eq '1') { '开发环境' } else { '生产环境' })

# Google OAuth 客户端凭据
GOOGLE_CLIENT_ID=$googleClientId
GOOGLE_CLIENT_SECRET=$googleClientSecret

# OAuth 重定向 URL
GOOGLE_REDIRECT_URL=$googleRedirectUrl

# OAuth 行为配置
OAUTH_STATE_EXPIRY=$oauthStateExpiry
OAUTH_AUTO_CREATE_USER=$oauthAutoCreateUser

# OAuth 登录时允许的企业邮箱域名（留空允许所有）
OAUTH_ALLOWED_DOMAINS=$allowedDomains

# ========================================
# JWT 配置
# ========================================
JWT_SECRET=$jwtSecret

# ========================================
# 安全配置
# ========================================
# 强制 HTTPS（生产环境必须为 true）
FORCE_HTTPS=$forceHttps

# Cookie 安全配置
COOKIE_SECURE=$cookieSecure
COOKIE_SAME_SITE=$cookieSameSite

# CORS 配置
ALLOWED_ORIGINS=$allowedOrigins

# ========================================
# 数据库配置（使用默认值）
# ========================================
DB_TYPE=sqlite
SQLITE_PATH=./auth.db

# ========================================
# 服务器配置
# ========================================
SERVER_PORT=8081
"@

# 写入文件
$envContent | Out-File -FilePath $envFile -Encoding UTF8

Write-ColorOutput Green "✓ .env.local 文件已创建"
Write-Output ""

# 显示配置摘要
Write-ColorOutput Cyan "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
Write-ColorOutput Cyan "   配置摘要"
Write-ColorOutput Cyan "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
Write-Output ""
Write-ColorOutput Green "客户端 ID:      $($googleClientId.Substring(0, [Math]::Min(20, $googleClientId.Length)))..."
Write-ColorOutput Green "重定向 URL:     $googleRedirectUrl"
Write-ColorOutput Green "HTTPS 强制:     $forceHttps"
Write-ColorOutput Green "Cookie 安全:    $cookieSecure"
Write-ColorOutput Green "允许域名:       $(if ($allowedDomains) { $allowedDomains } else { '所有域名' })"
Write-Output ""

# 安全提醒
Write-ColorOutput Yellow "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
Write-ColorOutput Yellow "   ⚠️  重要安全提醒"
Write-ColorOutput Yellow "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
Write-Output ""
Write-ColorOutput Red "• 不要将 .env.local 提交到 Git"
Write-ColorOutput Red "• 定期轮换 Google Client Secret"
Write-ColorOutput Red "• 生产环境必须使用 HTTPS"
Write-Output ""

# 检查 .gitignore
$gitignore = Join-Path $projectRoot ".gitignore"
if (Test-Path $gitignore) {
    $gitignoreContent = Get-Content $gitignore -Raw
    if ($gitignoreContent -match ".env.local") {
        Write-ColorOutput Green "✓ .gitignore 已配置"
    } else {
        Write-ColorOutput Yellow "建议添加以下内容到 .gitignore:"
        Write-Output ""
        Write-Output ".env.local"
        Write-Output ".env.*.local"
        Write-Output ""
    }
}

# 下一步指引
Write-ColorOutput Cyan "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
Write-ColorOutput Cyan "   下一步"
Write-ColorOutput Cyan "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
Write-Output ""
Write-Output "1. 启动服务："
Write-ColorOutput Green "   cd services\auth-service"
Write-ColorOutput Green "   go run cmd\main.go"
Write-Output ""
Write-Output "2. 测试 OAuth 登录："
Write-ColorOutput Green "   访问 http://localhost:8081/api/v1/auth/oauth/google"
Write-Output ""
Write-Output "3. 查看完整文档："
Write-ColorOutput Green "   docs\GOOGLE_CLOUD_CONSOLE_SETUP.md"
Write-Output ""
Write-ColorOutput Green "✓ 配置完成！"
