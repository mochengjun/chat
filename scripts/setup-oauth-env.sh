#!/bin/bash

# ========================================
# OAuth 环境变量配置助手
# ========================================
# 此脚本帮助您快速配置 Google OAuth 环境变量
# 使用方法: ./setup-oauth-env.sh

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 项目根目录
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AUTH_SERVICE_DIR="$PROJECT_ROOT/services/auth-service"
ENV_FILE="$AUTH_SERVICE_DIR/.env.local"

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}   Google OAuth 环境变量配置助手${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# 检查是否已存在 .env.local
if [ -f "$ENV_FILE" ]; then
    echo -e "${YELLOW}警告: .env.local 文件已存在${NC}"
    read -p "是否覆盖现有配置? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}操作已取消${NC}"
        exit 1
    fi
    # 备份现有文件
    cp "$ENV_FILE" "$ENV_FILE.backup.$(date +%Y%m%d_%H%M%S)"
    echo -e "${GREEN}✓ 已备份现有配置${NC}"
fi

echo ""
echo -e "${BLUE}请输入您的 Google OAuth 凭据信息：${NC}"
echo -e "${YELLOW}（可从 Google Cloud Console 获取）${NC}"
echo ""

# 收集配置信息
read -p "$(echo -e ${GREEN}Google Client ID:${NC} )" GOOGLE_CLIENT_ID
read -p "$(echo -e ${GREEN}Google Client Secret:${NC} )" GOOGLE_CLIENT_SECRET

# 选择环境
echo ""
echo -e "${BLUE}选择部署环境：${NC}"
echo "1) 开发环境 (localhost)"
echo "2) 生产环境"
read -p "请选择 (1/2): " env_choice

case $env_choice in
    1)
        GOOGLE_REDIRECT_URL="http://localhost:8081/api/v1/auth/oauth/google/callback"
        FORCE_HTTPS="false"
        COOKIE_SECURE="false"
        ALLOWED_ORIGINS="http://localhost:3000,http://localhost:5173,http://localhost:8081"
        ;;
    2)
        read -p "$(echo -e ${GREEN}生产域名 (例如: chat.yourcompany.com):${NC} )" PRODUCTION_DOMAIN
        GOOGLE_REDIRECT_URL="https://$PRODUCTION_DOMAIN/api/v1/auth/oauth/google/callback"
        FORCE_HTTPS="true"
        COOKIE_SECURE="true"
        ALLOWED_ORIGINS="https://$PRODUCTION_DOMAIN"
        ;;
    *)
        echo -e "${RED}无效选择${NC}"
        exit 1
        ;;
esac

# 可选配置
echo ""
echo -e "${BLUE}可选配置（按 Enter 使用默认值）：${NC}"
read -p "$(echo -e ${GREEN}允许的企业邮箱域名 (留空允许所有):${NC} )" ALLOWED_DOMAINS
read -p "$(echo -e ${GREEN}JWT Secret (至少32字符) [自动生成]:${NC} )" JWT_SECRET

# 生成 JWT Secret（如果未提供）
if [ -z "$JWT_SECRET" ]; then
    JWT_SECRET=$(openssl rand -base64 32)
    echo -e "${YELLOW}✓ 已生成随机 JWT Secret${NC}"
fi

# 验证 JWT Secret 长度
if [ ${#JWT_SECRET} -lt 32 ]; then
    echo -e "${RED}错误: JWT Secret 必须至少 32 个字符${NC}"
    exit 1
fi

# OAuth 行为配置
OAUTH_STATE_EXPIRY=${OAUTH_STATE_EXPIRY:-300}
OAUTH_AUTO_CREATE_USER=${OAUTH_AUTO_CREATE_USER:-true}
COOKIE_SAME_SITE=${COOKIE_SAME_SITE:-Lax}

# 创建 .env.local 文件
echo ""
echo -e "${BLUE}正在创建 .env.local 文件...${NC}"

cat > "$ENV_FILE" << EOF
# ========================================
# Google OAuth 配置
# ========================================
# 生成时间: $(date)
# 环境: $([ $env_choice -eq 1 ] && echo "开发环境" || echo "生产环境")

# Google OAuth 客户端凭据
GOOGLE_CLIENT_ID=$GOOGLE_CLIENT_ID
GOOGLE_CLIENT_SECRET=$GOOGLE_CLIENT_SECRET

# OAuth 重定向 URL
GOOGLE_REDIRECT_URL=$GOOGLE_REDIRECT_URL

# OAuth 行为配置
OAUTH_STATE_EXPIRY=$OAUTH_STATE_EXPIRY
OAUTH_AUTO_CREATE_USER=$OAUTH_AUTO_CREATE_USER

# OAuth 登录时允许的企业邮箱域名（留空允许所有）
OAUTH_ALLOWED_DOMAINS=$ALLOWED_DOMAINS

# ========================================
# JWT 配置
# ========================================
JWT_SECRET=$JWT_SECRET

# ========================================
# 安全配置
# ========================================
# 强制 HTTPS（生产环境必须为 true）
FORCE_HTTPS=$FORCE_HTTPS

# Cookie 安全配置
COOKIE_SECURE=$COOKIE_SECURE
COOKIE_SAME_SITE=$COOKIE_SAME_SITE

# CORS 配置
ALLOWED_ORIGINS=$ALLOWED_ORIGINS

# ========================================
# 数据库配置（使用默认值）
# ========================================
DB_TYPE=sqlite
SQLITE_PATH=./auth.db

# ========================================
# 服务器配置
# ========================================
SERVER_PORT=8081
EOF

echo -e "${GREEN}✓ .env.local 文件已创建${NC}"
echo ""

# 显示配置摘要
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}   配置摘要${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${GREEN}客户端 ID:${NC}      ${GOOGLE_CLIENT_ID:0:20}..."
echo -e "${GREEN}重定向 URL:${NC}     $GOOGLE_REDIRECT_URL"
echo -e "${GREEN}HTTPS 强制:${NC}     $FORCE_HTTPS"
echo -e "${GREEN}Cookie 安全:${NC}    $COOKIE_SECURE"
echo -e "${GREEN}允许域名:${NC}       ${ALLOWED_DOMAINS:-所有域名}"
echo ""

# 安全提醒
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}   ⚠️  重要安全提醒${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${RED}• 不要将 .env.local 提交到 Git${NC}"
echo -e "${RED}• 定期轮换 Google Client Secret${NC}"
echo -e "${RED}• 生产环境必须使用 HTTPS${NC}"
echo ""

# 检查 .gitignore
GITIGNORE="$PROJECT_ROOT/.gitignore"
if [ -f "$GITIGNORE" ]; then
    if grep -q ".env.local" "$GITIGNORE"; then
        echo -e "${GREEN}✓ .gitignore 已配置${NC}"
    else
        echo -e "${YELLOW}建议添加以下内容到 .gitignore:${NC}"
        echo ""
        echo ".env.local"
        echo ".env.*.local"
        echo ""
    fi
fi

# 下一步指引
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}   下一步${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "1. 启动服务："
echo -e "   ${GREEN}cd services/auth-service && go run cmd/main.go${NC}"
echo ""
echo "2. 测试 OAuth 登录："
echo -e "   ${GREEN}访问 http://localhost:8081/api/v1/auth/oauth/google${NC}"
echo ""
echo "3. 查看完整文档："
echo -e "   ${GREEN}docs/GOOGLE_CLOUD_CONSOLE_SETUP.md${NC}"
echo ""
echo -e "${GREEN}✓ 配置完成！${NC}"
