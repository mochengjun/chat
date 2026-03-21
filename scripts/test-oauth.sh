#!/bin/bash

# ========================================
# OAuth 登录流程测试脚本
# ========================================
# 此脚本测试 OAuth 登录流程的各个步骤

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置
AUTH_SERVICE_URL="http://localhost:8081"
TIMEOUT=5

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}   OAuth 登录流程测试${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# 测试函数
test_step() {
    local step_name=$1
    local url=$2
    local expected_status=$3
    
    echo -e "${YELLOW}测试: $step_name${NC}"
    echo -e "  URL: $url"
    
    response=$(curl -s -w "\n%{http_code}" -X GET "$url" --max-time $TIMEOUT 2>&1 || echo "000")
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')
    
    if [ "$http_code" = "$expected_status" ]; then
        echo -e "  ${GREEN}✓ 状态码: $http_code${NC}"
        return 0
    else
        echo -e "  ${RED}✗ 状态码: $http_code (期望: $expected_status)${NC}"
        return 1
    fi
}

# 测试计数
total_tests=0
passed_tests=0

run_test() {
    local test_name=$1
    shift
    
    total_tests=$((total_tests + 1))
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}测试 $total_tests: $test_name${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    if "$@"; then
        passed_tests=$((passed_tests + 1))
        echo -e "${GREEN}✓ 测试通过${NC}"
    else
        echo -e "${RED}✗ 测试失败${NC}"
    fi
}

# ========================================
# 测试 1: 健康检查
# ========================================
run_test "服务健康检查" test_step "健康检查" "$AUTH_SERVICE_URL/health" "200"

# ========================================
# 测试 2: OAuth 配置检查
# ========================================
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}测试 2: OAuth 配置检查${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo ""
echo -e "${YELLOW}检查 OAuth 登录端点...${NC}"
response=$(curl -s -I "$AUTH_SERVICE_URL/api/v1/auth/oauth/google" 2>&1)
http_code=$(echo "$response" | grep -i "HTTP/" | head -1 | awk '{print $2}')

if [ "$http_code" = "307" ] || [ "$http_code" = "302" ]; then
    echo -e "  ${GREEN}✓ OAuth 端点可访问 (状态码: $http_code)${NC}"
    
    # 检查重定向位置
    location=$(echo "$response" | grep -i "location:" | head -1 | cut -d' ' -f2 | tr -d '\r')
    if echo "$location" | grep -q "accounts.google.com"; then
        echo -e "  ${GREEN}✓ 正确重定向到 Google${NC}"
        echo -e "  ${BLUE}  重定向 URL: ${location:0:80}...${NC}"
        passed_tests=$((passed_tests + 1))
    else
        echo -e "  ${RED}✗ 未重定向到 Google${NC}"
        echo -e "  ${YELLOW}  Location: $location${NC}"
    fi
elif [ "$http_code" = "503" ]; then
    echo -e "  ${RED}✗ OAuth 未配置 (状态码: 503)${NC}"
    echo -e "  ${YELLOW}  请配置 GOOGLE_CLIENT_ID 和 GOOGLE_CLIENT_SECRET${NC}"
else
    echo -e "  ${RED}✗ OAuth 端点不可用 (状态码: $http_code)${NC}"
fi
total_tests=$((total_tests + 1))

# ========================================
# 测试 3: OAuth URL 参数验证
# ========================================
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}测试 3: OAuth URL 参数验证${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo ""
echo -e "${YELLOW}检查 OAuth URL 参数...${NC}"

# 获取重定向 URL
redirect_url=$(curl -s -I "$AUTH_SERVICE_URL/api/v1/auth/oauth/google" 2>&1 | grep -i "location:" | cut -d' ' -f2 | tr -d '\r\n')

if [ -n "$redirect_url" ]; then
    echo -e "  ${BLUE}完整重定向 URL:${NC}"
    echo -e "  $redirect_url"
    echo ""
    
    # 检查必需参数
    params_valid=true
    
    if echo "$redirect_url" | grep -q "client_id="; then
        echo -e "  ${GREEN}✓ client_id 参数存在${NC}"
    else
        echo -e "  ${RED}✗ client_id 参数缺失${NC}"
        params_valid=false
    fi
    
    if echo "$redirect_url" | grep -q "redirect_uri="; then
        echo -e "  ${GREEN}✓ redirect_uri 参数存在${NC}"
    else
        echo -e "  ${RED}✗ redirect_uri 参数缺失${NC}"
        params_valid=false
    fi
    
    if echo "$redirect_url" | grep -q "state="; then
        echo -e "  ${GREEN}✓ state 参数存在${NC}"
        state_param=$(echo "$redirect_url" | grep -oP 'state=\K[^&]+')
        echo -e "  ${BLUE}  State 值: $state_param${NC}"
    else
        echo -e "  ${RED}✗ state 参数缺失${NC}"
        params_valid=false
    fi
    
    if echo "$redirect_url" | grep -q "scope="; then
        echo -e "  ${GREEN}✓ scope 参数存在${NC}"
        scope_param=$(echo "$redirect_url" | grep -oP 'scope=\K[^&]+' | python3 -c "import sys; from urllib.parse import unquote; print(unquote(sys.stdin.read()))" 2>/dev/null || echo "无法解析")
        echo -e "  ${BLUE}  Scope: $scope_param${NC}"
    else
        echo -e "  ${RED}✗ scope 参数缺失${NC}"
        params_valid=false
    fi
    
    total_tests=$((total_tests + 1))
    if [ "$params_valid" = true ]; then
        passed_tests=$((passed_tests + 1))
        echo -e "${GREEN}✓ 所有必需参数都存在${NC}"
    else
        echo -e "${RED}✗ 部分参数缺失${NC}"
    fi
else
    echo -e "  ${RED}✗ 无法获取重定向 URL${NC}"
    total_tests=$((total_tests + 1))
fi

# ========================================
# 测试 4: 无效 State 验证
# ========================================
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}测试 4: 无效 State 验证${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo ""
echo -e "${YELLOW}测试无效 state 参数...${NC}"
response=$(curl -s "$AUTH_SERVICE_URL/api/v1/auth/oauth/google/callback?code=test&state=invalid_state" 2>&1)

if echo "$response" | grep -qi "error\|unauthorized\|invalid"; then
    echo -e "  ${GREEN}✓ 正确拒绝无效 state${NC}"
    passed_tests=$((passed_tests + 1))
else
    echo -e "  ${RED}✗ 未正确验证 state${NC}"
fi
total_tests=$((total_tests + 1))

# ========================================
# 测试 5: CORS 配置检查
# ========================================
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}测试 5: CORS 配置检查${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo ""
echo -e "${YELLOW}检查 CORS 头...${NC}"

# OPTIONS 预检请求
cors_response=$(curl -s -I -X OPTIONS "$AUTH_SERVICE_URL/api/v1/auth/oauth/google" \
    -H "Origin: http://localhost:3000" \
    -H "Access-Control-Request-Method: GET" 2>&1)

total_tests=$((total_tests + 1))

if echo "$cors_response" | grep -qi "Access-Control-Allow-Origin"; then
    allow_origin=$(echo "$cors_response" | grep -i "Access-Control-Allow-Origin:" | cut -d' ' -f2 | tr -d '\r')
    echo -e "  ${GREEN}✓ CORS 已配置${NC}"
    echo -e "  ${BLUE}  Allow-Origin: $allow_origin${NC}"
    passed_tests=$((passed_tests + 1))
else
    echo -e "  ${YELLOW}⚠ CORS 未配置或未返回头${NC}"
fi

# ========================================
# 测试总结
# ========================================
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}   测试总结${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

percentage=$((passed_tests * 100 / total_tests))
echo -e "总测试数: $total_tests"
echo -e "通过: ${GREEN}$passed_tests${NC}"
echo -e "失败: ${RED}$((total_tests - passed_tests))${NC}"
echo -e "通过率: ${BLUE}$percentage%${NC}"
echo ""

if [ $passed_tests -eq $total_tests ]; then
    echo -e "${GREEN}✓ 所有测试通过！${NC}"
    echo ""
    echo -e "${BLUE}下一步：${NC}"
    echo "1. 在浏览器中访问: http://localhost:8081/api/v1/auth/oauth/google"
    echo "2. 使用 Google 账号登录"
    echo "3. 查看回调处理是否正确"
    exit 0
elif [ $percentage -ge 60 ]; then
    echo -e "${YELLOW}⚠ 大部分测试通过，请检查失败项${NC}"
    exit 1
else
    echo -e "${RED}✗ 多数测试失败，请检查配置${NC}"
    echo ""
    echo -e "${YELLOW}常见问题：${NC}"
    echo "1. 服务未启动 - 运行: cd services/auth-service && go run cmd/main.go"
    echo "2. OAuth 未配置 - 检查 .env.local 文件"
    echo "3. 端口错误 - 确认服务运行在 8081 端口"
    exit 1
fi
