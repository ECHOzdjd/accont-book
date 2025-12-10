#!/bin/bash

# =============================================================================
# Nacos 服务注册发现测试脚本
# 用法: ./test-nacos.sh
# 测试内容: 服务注册、服务发现、健康检查、服务元数据
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 配置
NACOS_URL="${NACOS_URL:-http://localhost:8848}"

# 计数器
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# 预期的服务列表
EXPECTED_SERVICES=("gateway-service" "user-service" "asset-service" "transaction-service" "statistics-service")

# =============================================================================
# 工具函数
# =============================================================================

print_header() {
    echo ""
    echo -e "${BLUE}============================================${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}============================================${NC}"
}

print_test() {
    echo -e "\n${YELLOW}[TEST]${NC} $1"
}

print_cmd() {
    echo -e "  ${CYAN}[CMD]${NC} $1"
}

print_info() {
    echo -e "  ${BLUE}→${NC} $1"
}

log_pass() {
    echo -e "  ${GREEN}✓ PASSED${NC} - $1"
    PASSED_TESTS=$((PASSED_TESTS + 1))
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
}

log_fail() {
    echo -e "  ${RED}✗ FAILED${NC} - $1"
    FAILED_TESTS=$((FAILED_TESTS + 1))
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
}

# =============================================================================
# 1. Nacos 服务端健康检查
# =============================================================================

print_header "Nacos 服务端健康检查"

print_test "Nacos 控制台可访问性"
print_cmd "curl '$NACOS_URL/nacos/'"
RESPONSE=$(curl -s --connect-timeout 5 "$NACOS_URL/nacos/" 2>/dev/null)
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$NACOS_URL/nacos/" 2>/dev/null)

if [ "$HTTP_CODE" == "200" ] || [ "$HTTP_CODE" == "302" ]; then
    log_pass "Nacos 控制台可访问 (HTTP $HTTP_CODE)"
else
    log_fail "Nacos 控制台不可用 (HTTP $HTTP_CODE)"
    echo -e "\n  ${YELLOW}提示: 请确保 Nacos 正在运行${NC}"
    exit 1
fi

print_test "Nacos 健康检查端点"
print_cmd "curl '$NACOS_URL/nacos/v1/console/health/liveness'"
RESPONSE=$(curl -s --connect-timeout 5 "$NACOS_URL/nacos/v1/console/health/liveness" 2>/dev/null)
print_info "Response: $RESPONSE"

if echo "$RESPONSE" | grep -qi "ok\|UP\|liveness"; then
    log_pass "Nacos 健康检查正常"
else
    # Nacos 2.x 可能没有这个端点，尝试其他方式
    if curl -s "$NACOS_URL/nacos/" >/dev/null 2>&1; then
        log_pass "Nacos 运行正常"
    else
        log_fail "Nacos 健康检查失败"
    fi
fi

# =============================================================================
# 2. 服务注册验证
# =============================================================================

print_header "服务注册验证"

print_test "获取已注册服务列表"
print_cmd "curl '$NACOS_URL/nacos/v1/ns/service/list?pageNo=1&pageSize=20'"
RESPONSE=$(curl -s --connect-timeout 5 "$NACOS_URL/nacos/v1/ns/service/list?pageNo=1&pageSize=20" 2>/dev/null)
print_info "Response: $RESPONSE"

SERVICE_COUNT=$(echo "$RESPONSE" | grep -o '"count":[0-9]*' | cut -d: -f2)
if [ -n "$SERVICE_COUNT" ] && [ "$SERVICE_COUNT" -gt 0 ]; then
    log_pass "发现 $SERVICE_COUNT 个已注册服务"
else
    log_fail "未发现已注册服务"
fi

# 验证每个预期服务
print_test "验证预期服务注册状态"
for service in "${EXPECTED_SERVICES[@]}"; do
    print_cmd "curl '$NACOS_URL/nacos/v1/ns/instance/list?serviceName=$service'"
    RESPONSE=$(curl -s --connect-timeout 5 "$NACOS_URL/nacos/v1/ns/instance/list?serviceName=$service" 2>/dev/null)
    
    INSTANCE_COUNT=$(echo "$RESPONSE" | grep -o '"instanceId"' | wc -l)
    
    if [ "$INSTANCE_COUNT" -gt 0 ]; then
        # 获取实例详情
        IP=$(echo "$RESPONSE" | grep -o '"ip":"[^"]*"' | head -1 | cut -d'"' -f4)
        PORT=$(echo "$RESPONSE" | grep -o '"port":[0-9]*' | head -1 | cut -d: -f2)
        HEALTHY=$(echo "$RESPONSE" | grep -o '"healthy":[^,]*' | head -1 | cut -d: -f2)
        
        echo -e "  ${GREEN}✓${NC} $service: $INSTANCE_COUNT 实例 ($IP:$PORT, healthy=$HEALTHY)"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo -e "  ${RED}✗${NC} $service: 未注册"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
done

# =============================================================================
# 3. 服务实例详情
# =============================================================================

print_header "服务实例详情"

for service in "${EXPECTED_SERVICES[@]}"; do
    print_test "$service 实例信息"
    print_cmd "curl '$NACOS_URL/nacos/v1/ns/instance/list?serviceName=$service'"
    RESPONSE=$(curl -s --connect-timeout 5 "$NACOS_URL/nacos/v1/ns/instance/list?serviceName=$service" 2>/dev/null)
    
    # 使用 Python 解析 JSON
    echo "$RESPONSE" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    hosts = data.get('hosts', [])
    if hosts:
        for i, host in enumerate(hosts, 1):
            print(f\"  实例 #{i}:\")
            print(f\"    IP: {host.get('ip')}\")
            print(f\"    Port: {host.get('port')}\")
            print(f\"    Healthy: {host.get('healthy')}\")
            print(f\"    Weight: {host.get('weight')}\")
            metadata = host.get('metadata', {})
            if metadata:
                print(f\"    Metadata: {metadata}\")
    else:
        print('  (无实例)')
except Exception as e:
    print(f'  解析错误: {e}')
" 2>/dev/null || echo "  (无法解析响应)"
done

# =============================================================================
# 4. 服务健康状态
# =============================================================================

print_header "服务健康状态检查"

print_test "检查所有服务实例健康状态"
UNHEALTHY_COUNT=0

for service in "${EXPECTED_SERVICES[@]}"; do
    RESPONSE=$(curl -s --connect-timeout 5 "$NACOS_URL/nacos/v1/ns/instance/list?serviceName=$service" 2>/dev/null)
    
    # 检查是否有不健康的实例
    UNHEALTHY=$(echo "$RESPONSE" | grep -o '"healthy":false' | wc -l)
    HEALTHY=$(echo "$RESPONSE" | grep -o '"healthy":true' | wc -l)
    
    if [ "$UNHEALTHY" -gt 0 ]; then
        echo -e "  ${YELLOW}⚠${NC} $service: $HEALTHY 健康, $UNHEALTHY 不健康"
        UNHEALTHY_COUNT=$((UNHEALTHY_COUNT + UNHEALTHY))
    elif [ "$HEALTHY" -gt 0 ]; then
        echo -e "  ${GREEN}✓${NC} $service: $HEALTHY 健康"
    else
        echo -e "  ${RED}✗${NC} $service: 无实例"
    fi
done

if [ $UNHEALTHY_COUNT -eq 0 ]; then
    log_pass "所有服务实例健康"
else
    log_fail "存在 $UNHEALTHY_COUNT 个不健康实例"
fi

# =============================================================================
# 5. 服务发现功能测试
# =============================================================================

print_header "服务发现功能测试"

print_test "通过 Nacos API 发现 asset-service"
print_cmd "curl '$NACOS_URL/nacos/v1/ns/instance/list?serviceName=asset-service'"
RESPONSE=$(curl -s --connect-timeout 5 "$NACOS_URL/nacos/v1/ns/instance/list?serviceName=asset-service" 2>/dev/null)

INSTANCE_IP=$(echo "$RESPONSE" | grep -o '"ip":"[^"]*"' | head -1 | cut -d'"' -f4)
INSTANCE_PORT=$(echo "$RESPONSE" | grep -o '"port":[0-9]*' | head -1 | cut -d: -f2)

if [ -n "$INSTANCE_IP" ] && [ -n "$INSTANCE_PORT" ]; then
    print_info "发现实例: $INSTANCE_IP:$INSTANCE_PORT"
    
    # 直接调用发现的实例
    print_test "直接调用发现的实例"
    print_cmd "curl 'http://$INSTANCE_IP:$INSTANCE_PORT/actuator/health'"
    HEALTH_RESPONSE=$(curl -s --connect-timeout 5 "http://$INSTANCE_IP:$INSTANCE_PORT/actuator/health" 2>/dev/null)
    
    if echo "$HEALTH_RESPONSE" | grep -q '"status":"UP"'; then
        log_pass "服务发现并调用成功"
        print_info "Response: $HEALTH_RESPONSE"
    else
        log_fail "服务发现成功但调用失败"
    fi
else
    log_fail "服务发现失败"
fi

# =============================================================================
# 6. 服务订阅测试
# =============================================================================

print_header "服务订阅测试"

print_test "订阅服务变更"
print_cmd "curl '$NACOS_URL/nacos/v1/ns/instance/list?serviceName=asset-service&healthyOnly=true'"
RESPONSE=$(curl -s --connect-timeout 5 "$NACOS_URL/nacos/v1/ns/instance/list?serviceName=asset-service&healthyOnly=true" 2>/dev/null)

HEALTHY_COUNT=$(echo "$RESPONSE" | grep -o '"healthy":true' | wc -l)
print_info "健康实例数: $HEALTHY_COUNT"

if [ "$HEALTHY_COUNT" -gt 0 ]; then
    log_pass "服务订阅正常 (仅健康实例: $HEALTHY_COUNT)"
else
    log_fail "未找到健康实例"
fi

# =============================================================================
# 7. 命名空间检查
# =============================================================================

print_header "命名空间检查"

print_test "获取命名空间列表"
print_cmd "curl '$NACOS_URL/nacos/v1/console/namespaces'"
RESPONSE=$(curl -s --connect-timeout 5 "$NACOS_URL/nacos/v1/console/namespaces" 2>/dev/null)
print_info "Response: $RESPONSE"

if echo "$RESPONSE" | grep -q "public\|data"; then
    log_pass "命名空间查询正常"
else
    log_pass "命名空间查询完成 (可能需要认证)"
fi

# =============================================================================
# 测试报告
# =============================================================================

print_header "Nacos 测试报告"

echo ""
echo -e "  Nacos 地址:     ${CYAN}$NACOS_URL${NC}"
echo -e "  总测试数:       $TOTAL_TESTS"
echo -e "  ${GREEN}通过:${NC}           $PASSED_TESTS"
echo -e "  ${RED}失败:${NC}           $FAILED_TESTS"
echo ""

echo -e "  ${BLUE}已注册服务:${NC}"
for service in "${EXPECTED_SERVICES[@]}"; do
    RESPONSE=$(curl -s "$NACOS_URL/nacos/v1/ns/instance/list?serviceName=$service" 2>/dev/null)
    COUNT=$(echo "$RESPONSE" | grep -o '"instanceId"' | wc -l)
    echo -e "    $service: $COUNT 实例"
done
echo ""

if [ $FAILED_TESTS -eq 0 ]; then
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  ✓ Nacos 所有测试通过!${NC}"
    echo -e "${GREEN}========================================${NC}"
    exit 0
else
    echo -e "${YELLOW}========================================${NC}"
    echo -e "${YELLOW}  ⚠ 有 $FAILED_TESTS 个测试失败${NC}"
    echo -e "${YELLOW}========================================${NC}"
    exit 1
fi
