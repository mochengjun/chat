#!/bin/bash
# ============================================================
# 阿里云服务器防火墙配置脚本
# 服务器IP: 8.130.55.126
# ============================================================

set -e

echo "=========================================="
echo "配置阿里云服务器防火墙规则"
echo "服务器IP: 8.130.55.126"
echo "=========================================="

# 检查是否为 root 用户
if [ "$EUID" -ne 0 ]; then
    echo "请使用 root 权限运行此脚本"
    exit 1
fi

# 检查 firewalld 是否安装
if command -v firewall-cmd &> /dev/null; then
    echo "使用 firewalld 配置防火墙..."

    # 开放必要端口
    # HTTP 端口 (80) - 通过 nginx 访问
    firewall-cmd --permanent --add-port=80/tcp
    echo "已开放端口: 80 (HTTP)"

    # HTTPS 端口 (443) - SSL 加密访问
    firewall-cmd --permanent --add-port=443/tcp
    echo "已开放端口: 443 (HTTPS)"

    # API 端口 (8081) - 直接访问 API
    firewall-cmd --permanent --add-port=8081/tcp
    echo "已开放端口: 8081 (API)"

    # WebSocket 端口 (已包含在 80/443/8081 中)

    # SSH 端口 (22) - 确保开放
    firewall-cmd --permanent --add-service=ssh
    echo "已开放端口: 22 (SSH)"

    # 重新加载防火墙配置
    firewall-cmd --reload
    echo "防火墙配置已重新加载"

    # 显示当前开放的端口
    echo ""
    echo "当前开放的端口:"
    firewall-cmd --list-ports

elif command -v ufw &> /dev/null; then
    echo "使用 ufw 配置防火墙..."

    # 开放必要端口
    ufw allow 22/tcp comment 'SSH'
    ufw allow 80/tcp comment 'HTTP'
    ufw allow 443/tcp comment 'HTTPS'
    ufw allow 8081/tcp comment 'API'

    # 启用防火墙
    ufw --force enable

    echo "ufw 防火墙配置完成"
    ufw status

elif command -v iptables &> /dev/null; then
    echo "使用 iptables 配置防火墙..."

    # 开放必要端口
    iptables -A INPUT -p tcp --dport 22 -j ACCEPT
    iptables -A INPUT -p tcp --dport 80 -j ACCEPT
    iptables -A INPUT -p tcp --dport 443 -j ACCEPT
    iptables -A INPUT -p tcp --dport 8081 -j ACCEPT

    # 保存规则
    if command -v iptables-save &> /dev/null; then
        iptables-save > /etc/iptables/rules.v4
        echo "iptables 规则已保存"
    fi

    echo "iptables 防火墙配置完成"
    iptables -L -n

else
    echo "警告: 未检测到支持的防火墙工具 (firewalld/ufw/iptables)"
    echo "请手动配置防火墙规则"
fi

echo ""
echo "=========================================="
echo "防火墙配置完成!"
echo "已开放端口:"
echo "  - 22 (SSH)"
echo "  - 80 (HTTP)"
echo "  - 443 (HTTPS)"
echo "  - 8081 (API)"
echo "=========================================="
echo ""
echo "重要提示:"
echo "1. 请确保阿里云安全组也开放了这些端口"
echo "2. 登录阿里云控制台 -> 云服务器ECS -> 安全组"
echo "3. 添加入方向规则，开放 80, 443, 8081 端口"
