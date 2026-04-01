#!/bin/bash
# ============================================================
# 阿里云服务器一键部署脚本
# 服务器IP: 8.130.55.126
# 使用方式: ./deploy-to-aliyun.sh [ssh-user]
# ============================================================

set -e

# 配置
SERVER_IP="8.130.55.126"
SSH_USER="${1:-root}"
PROJECT_NAME="chat"
REMOTE_PATH="/opt/${PROJECT_NAME}"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 获取脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

echo "=========================================="
echo "阿里云服务器一键部署"
echo "服务器: ${SERVER_IP}"
echo "用户: ${SSH_USER}"
echo "项目路径: ${REMOTE_PATH}"
echo "=========================================="

# 检查 SSH 连接
log_info "测试 SSH 连接..."
if ! ssh -o ConnectTimeout=10 -o BatchMode=yes ${SSH_USER}@${SERVER_IP} "echo 'SSH连接成功'" 2>/dev/null; then
    log_error "无法连接到服务器 ${SSH_USER}@${SERVER_IP}"
    log_info "请确保:"
    echo "  1. 服务器可访问"
    echo "  2. SSH 密钥已配置 (或使用 ssh-agent)"
    echo "  3. 用户名正确"
    exit 1
fi
log_success "SSH 连接成功"

# 在服务器上检查 Docker
log_info "检查服务器 Docker 环境..."
ssh ${SSH_USER}@${SERVER_IP} << 'ENDSSH'
if ! command -v docker &> /dev/null; then
    echo "安装 Docker..."
    curl -fsSL https://get.docker.com | sh
    sudo usermod -aG docker $USER
fi

if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo "安装 Docker Compose..."
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
fi

echo "Docker 版本:"
docker --version
docker compose version 2>/dev/null || docker-compose --version
ENDSSH
log_success "Docker 环境检查完成"

# 配置防火墙
log_info "配置服务器防火墙..."
ssh ${SSH_USER}@${SERVER_IP} << 'ENDSSH'
if command -v firewall-cmd &> /dev/null; then
    echo "使用 firewalld..."
    sudo firewall-cmd --permanent --add-port=22/tcp
    sudo firewall-cmd --permanent --add-port=80/tcp
    sudo firewall-cmd --permanent --add-port=443/tcp
    sudo firewall-cmd --permanent --add-port=8081/tcp
    sudo firewall-cmd --reload
    echo "防火墙端口已开放: 22, 80, 443, 8081"
elif command -v ufw &> /dev/null; then
    echo "使用 ufw..."
    sudo ufw allow 22/tcp
    sudo ufw allow 80/tcp
    sudo ufw allow 443/tcp
    sudo ufw allow 8081/tcp
    sudo ufw --force enable
    echo "防火墙端口已开放: 22, 80, 443, 8081"
fi
ENDSSH
log_success "防火墙配置完成"

# 同步项目文件
log_info "同步项目文件到服务器..."
ssh ${SSH_USER}@${SERVER_IP} "mkdir -p ${REMOTE_PATH}"

# 排除不需要同步的文件
rsync -avz --progress \
    --exclude 'node_modules' \
    --exclude '.git' \
    --exclude 'dist' \
    --exclude 'build' \
    --exclude '*.log' \
    --exclude '.env.local' \
    --exclude 'uploads/*' \
    --exclude 'data/*' \
    --exclude 'logs/*' \
    ${PROJECT_ROOT}/ ${SSH_USER}@${SERVER_IP}:${REMOTE_PATH}/

log_success "项目文件同步完成"

# 部署应用
log_info "在服务器上部署应用..."
ssh ${SSH_USER}@${SERVER_IP} << ENDSSH
cd ${REMOTE_PATH}/deployments/docker

# 创建环境文件
if [ ! -f .env ]; then
    echo "创建 .env 文件..."
    cp .env.example .env

    # 生成安全密码
    JWT_SECRET=\$(openssl rand -base64 64 | tr -d '\n')
    DB_PASSWORD=\$(openssl rand -base64 24 | tr -d '\n')
    REDIS_PASSWORD=\$(openssl rand -base64 24 | tr -d '\n')

    # 更新环境变量
    sed -i "s/SERVER_HOST=.*/SERVER_HOST=${SERVER_IP}/" .env
    sed -i "s|ALLOWED_ORIGINS=.*|ALLOWED_ORIGINS=http://${SERVER_IP},http://${SERVER_IP}:80,http://${SERVER_IP}:8081|" .env
    sed -i "s/JWT_SECRET=.*/JWT_SECRET=\${JWT_SECRET}/" .env
    sed -i "s/POSTGRES_PASSWORD=.*/POSTGRES_PASSWORD=\${DB_PASSWORD}/" .env
    sed -i "s/REDIS_PASSWORD=.*/REDIS_PASSWORD=\${REDIS_PASSWORD}/" .env

    echo "环境变量已配置"
fi

# 创建必要的目录
mkdir -p nginx/ssl keys

# 停止旧容器
docker compose down 2>/dev/null || true

# 构建并启动
echo "构建 Docker 镜像..."
docker compose build --no-cache

echo "启动服务..."
docker compose up -d

echo "等待服务启动..."
sleep 15

# 检查服务状态
docker compose ps
ENDSSH

log_success "应用部署完成"

# 验证部署
log_info "验证服务状态..."
ssh ${SSH_USER}@${SERVER_IP} << ENDSSH
echo "检查服务健康状态..."

# 检查 API 服务
if curl -s http://localhost:8081/health | grep -q "ok\|healthy\|success"; then
    echo "✓ API 服务 (8081) 正常"
else
    echo "✗ API 服务 (8081) 异常"
fi

# 检查 Nginx 服务
if curl -s http://localhost/nginx-health | grep -q "healthy"; then
    echo "✓ Nginx 服务 (80) 正常"
else
    echo "✗ Nginx 服务 (80) 异常"
fi

# 检查通过 Nginx 的 API
if curl -s http://localhost/health | grep -q "ok\|healthy\|success"; then
    echo "✓ Nginx -> API 代理正常"
else
    echo "✗ Nginx -> API 代理异常"
fi

echo ""
echo "显示容器日志..."
docker compose -f ${REMOTE_PATH}/deployments/docker/docker-compose.yml logs --tail=50
ENDSSH

echo ""
echo "=========================================="
log_success "部署完成!"
echo "=========================================="
echo ""
echo "访问地址:"
echo "  - HTTP:   http://${SERVER_IP}"
echo "  - API:    http://${SERVER_IP}:8081"
echo "  - 健康检查: http://${SERVER_IP}/health"
echo "  - WebSocket: ws://${SERVER_IP}/api/v1/ws"
echo ""
echo "管理命令:"
echo "  ssh ${SSH_USER}@${SERVER_IP} 'cd ${REMOTE_PATH}/deployments/docker && ./deploy.sh status'"
echo "  ssh ${SSH_USER}@${SERVER_IP} 'cd ${REMOTE_PATH}/deployments/docker && ./deploy.sh logs'"
echo ""
log_warning "重要提示:"
echo "  1. 请确保阿里云安全组已开放端口: 80, 443, 8081"
echo "  2. 请妥善保管 .env 文件中的密码"
echo "  3. 建议配置 HTTPS (SSL证书)"
