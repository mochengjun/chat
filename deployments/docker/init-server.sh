#!/bin/bash
# ============================================================
# 阿里云服务器初始配置脚本
# 通过阿里云控制台"远程连接"执行此脚本
# ============================================================

echo "=========================================="
echo "阿里云服务器初始配置"
echo "=========================================="

# 1. 检查并启动SSH服务
echo ""
echo "=== 1. 检查SSH服务 ==="
if command -v systemctl &> /dev/null; then
    systemctl status sshd 2>/dev/null || systemctl status ssh 2>/dev/null
    echo ""
    echo "启动SSH服务..."
    systemctl start sshd 2>/dev/null || systemctl start ssh 2>/dev/null
    systemctl enable sshd 2>/dev/null || systemctl enable ssh 2>/dev/null
elif command -v service &> /dev/null; then
    service sshd status 2>/dev/null || service ssh status 2>/dev/null
    echo ""
    echo "启动SSH服务..."
    service sshd start 2>/dev/null || service ssh start 2>/dev/null
fi

# 2. 检查SSH端口
echo ""
echo "=== 2. 检查SSH监听端口 ==="
netstat -tlnp 2>/dev/null | grep -E ':22|sshd' || ss -tlnp | grep -E ':22|sshd'

# 3. 配置防火墙开放端口
echo ""
echo "=== 3. 配置防火墙 ==="
if command -v firewall-cmd &> /dev/null; then
    echo "使用 firewalld..."
    firewall-cmd --permanent --add-port=22/tcp
    firewall-cmd --permanent --add-port=80/tcp
    firewall-cmd --permanent --add-port=443/tcp
    firewall-cmd --permanent --add-port=8081/tcp
    firewall-cmd --reload
    firewall-cmd --list-ports
elif command -v ufw &> /dev/null; then
    echo "使用 ufw..."
    ufw allow 22/tcp
    ufw allow 80/tcp
    ufw allow 443/tcp
    ufw allow 8081/tcp
    ufw --force enable
    ufw status
else
    echo "未检测到防火墙，检查 iptables..."
    iptables -L -n | head -20
fi

# 4. 设置root密码 (如果需要密码登录)
echo ""
echo "=== 4. 设置root密码 (用于SSH登录) ==="
echo "请输入新的root密码 (输入时不显示):"
passwd root

# 5. 允许root通过SSH密码登录
echo ""
echo "=== 5. 配置SSH允许root登录 ==="
if [ -f /etc/ssh/sshd_config ]; then
    sed -i 's/#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
    sed -i 's/PermitRootLogin no/PermitRootLogin yes/' /etc/ssh/sshd_config
    sed -i 's/#PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
    sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
    echo "SSH配置已更新"

    # 重启SSH服务
    systemctl restart sshd 2>/dev/null || systemctl restart ssh 2>/dev/null || service sshd restart 2>/dev/null || service ssh restart 2>/dev/null
    echo "SSH服务已重启"
fi

# 6. 安装Docker (如果未安装)
echo ""
echo "=== 6. 检查Docker环境 ==="
if command -v docker &> /dev/null; then
    echo "Docker已安装:"
    docker --version
else
    echo "安装Docker..."
    curl -fsSL https://get.docker.com | sh
    systemctl start docker
    systemctl enable docker
    echo "Docker安装完成"
fi

# 安装Docker Compose
if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo "安装Docker Compose..."
    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    echo "Docker Compose安装完成"
fi

docker compose version 2>/dev/null || docker-compose --version

# 7. 显示状态
echo ""
echo "=========================================="
echo "配置完成!"
echo "=========================================="
echo ""
echo "请提供以下信息以便后续部署:"
echo "1. root密码 (刚刚设置的)"
echo "2. 或者提供SSH私钥"
echo ""
echo "服务器IP: 8.130.55.126"
echo "SSH端口: 22"
