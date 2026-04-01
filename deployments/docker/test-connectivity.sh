#!/bin/bash
# ============================================================
# 服务连通性测试脚本
# 测试服务器: 8.130.55.126
# ============================================================

# 配置
SERVER_IP="${1:-8.130.55.126}"
TIMEOUT=10

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

pass() { echo -e "${GREEN}✓ PASS${NC} $1"; }
fail() { echo -e "${RED}✗ FAIL${NC} $1"; }
info() { echo -e "${BLUE}➜${NC} $1"; }

echo "=========================================="
echo "服务连通性测试"
echo "服务器IP: ${SERVER_IP}"
echo "测试时间: $(date)"
echo "=========================================="
echo ""

# 测试函数
test_port() {
    local host=$1
    local port=$2
    local service=$3

    if timeout ${TIMEOUT} bash -c "echo > /dev/tcp/${host}/${port}" 2>/dev/null; then
        pass "${service} 端口 ${port} 可访问"
        return 0
    else
        fail "${service} 端口 ${port} 不可访问"
        return 1
    fi
}

test_http() {
    local url=$1
    local service=$2

    local response=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout ${TIMEOUT} "${url}" 2>/dev/null)

    if [ "${response}" = "200" ] || [ "${response}" = "401" ] || [ "${response}" = "404" ]; then
        pass "${service} HTTP 状态码: ${response}"
        return 0
    else
        fail "${service} HTTP 状态码: ${response}"
        return 1
    fi
}

test_websocket() {
    local url=$1

    # 使用 curl 测试 WebSocket 升级
    local response=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout ${TIMEOUT} \
        -H "Connection: Upgrade" \
        -H "Upgrade: websocket" \
        -H "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==" \
        -H "Sec-WebSocket-Version: 13" \
        "${url}" 2>/dev/null)

    if [ "${response}" = "101" ] || [ "${response}" = "400" ] || [ "${response}" = "401" ]; then
        pass "WebSocket 升级响应: ${response}"
        return 0
    else
        fail "WebSocket 升级响应: ${response}"
        return 1
    fi
}

# 记录测试结果
passed=0
failed=0

echo "=== 端口连通性测试 ==="
echo ""

# 测试 SSH 端口
if test_port "${SERVER_IP}" 22 "SSH"; then ((passed++)); else ((failed++)); fi

# 测试 HTTP 端口
if test_port "${SERVER_IP}" 80 "HTTP"; then ((passed++)); else ((failed++)); fi

# 测试 HTTPS 端口
if test_port "${SERVER_IP}" 443 "HTTPS"; then ((passed++)); else ((failed++)); fi

# 测试 API 端口
if test_port "${SERVER_IP}" 8081 "API"; then ((passed++)); else ((failed++)); fi

echo ""
echo "=== HTTP 服务测试 ==="
echo ""

# 测试 Nginx 健康检查
if test_http "http://${SERVER_IP}/nginx-health" "Nginx健康检查"; then ((passed++)); else ((failed++)); fi

# 测试 API 健康检查 (通过 Nginx)
if test_http "http://${SERVER_IP}/health" "API健康检查(Nginx代理)"; then ((passed++)); else ((failed++)); fi

# 测试 API 直接访问
if test_http "http://${SERVER_IP}:8081/health" "API健康检查(直接访问)"; then ((passed++)); else ((failed++)); fi

# 测试 API 根路径
if test_http "http://${SERVER_IP}/api/v1/" "API根路径"; then ((passed++)); else ((failed++)); fi

echo ""
echo "=== WebSocket 服务测试 ==="
echo ""

# 测试 WebSocket 升级
info "测试 WebSocket 升级请求..."
if test_websocket "http://${SERVER_IP}/api/v1/ws"; then ((passed++)); else ((failed++)); fi

echo ""
echo "=== 响应内容测试 ==="
echo ""

# 获取详细的健康检查响应
info "获取健康检查详情..."
health_response=$(curl -s --connect-timeout ${TIMEOUT} "http://${SERVER_IP}/health" 2>/dev/null)
if [ -n "${health_response}" ]; then
    info "健康检查响应: ${health_response}"
else
    fail "无法获取健康检查响应"
    ((failed++))
fi

echo ""
echo "=========================================="
echo "测试结果汇总"
echo "=========================================="
echo -e "${GREEN}通过: ${passed}${NC}"
echo -e "${RED}失败: ${failed}${NC}"
echo ""

if [ ${failed} -eq 0 ]; then
    echo -e "${GREEN}所有测试通过! 服务运行正常。${NC}"
    echo ""
    echo "访问地址:"
    echo "  - 主页: http://${SERVER_IP}"
    echo "  - API: http://${SERVER_IP}:8081"
    echo "  - 健康检查: http://${SERVER_IP}/health"
    echo "  - WebSocket: ws://${SERVER_IP}/api/v1/ws"
    exit 0
else
    echo -e "${RED}部分测试失败，请检查服务配置。${NC}"
    echo ""
    echo "排查建议:"
    echo "  1. 检查 Docker 服务状态: docker compose ps"
    echo "  2. 检查服务日志: docker compose logs"
    echo "  3. 检查防火墙: firewall-cmd --list-ports 或 ufw status"
    echo "  4. 检查阿里云安全组是否开放端口"
    exit 1
fi
