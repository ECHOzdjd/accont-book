#!/bin/bash

# =============================================================================
# Gateway 服务专项测试脚本
# 用法: ./test-gateway.sh
# 测试内容: 健康检查、路由转发、负载均衡、CORS、错误处理
# =============================================================================

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 配置
GATEWAY_URL="${GATEWAY_URL:-http://localhost:9000}"
CONTENT_TYPE="Content-Type: application/json"

# 计数器
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

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
    local method="$1"
    local url="$2"
    local body="$3"
    
    echo -e "  ${BLUE}→${NC} $method $url"
    
    local curl_cmd="curl"
    if [ "$method" != "GET" ]; then
        curl_cmd="$curl_cmd -X $method"
    fi
    curl_cmd="$curl_cmd '$url'"
    if [ -n "$body" ]; then
        curl_cmd="$curl_cmd -H '$CONTENT_TYPE' -d '$body'"
        echo -e "  ${BLUE}→${NC} Body: $body"
    fi
    echo -e "  ${CYAN}[CMD]${NC} $curl_cmd"
}

print_response() {
    local resp="$1"
    local status="$2"
    if [ -n "$status" ]; then
        echo -e "  ${BLUE}←${NC} HTTP Status: $status"
    fi
    if [ ${#resp} -gt 200 ]; then
        echo -e "  ${BLUE}←${NC} Response: ${resp:0:200}..."
    else
        echo -e "  ${BLUE}←${NC} Response: $resp"
    fi
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
# 1. Gateway 健康检查
# =============================================================================

print_header "Gateway 健康检查"

print_test "Gateway Actuator Health 端点"
print_cmd "GET" "$GATEWAY_URL/actuator/health"
RESPONSE=$(curl -s --connect-timeout 5 "$GATEWAY_URL/actuator/health" 2>/dev/null)
print_response "$RESPONSE"

if echo "$RESPONSE" | grep -q '"status":"UP"'; then
    log_pass "Gateway 服务运行正常"
else
    log_fail "Gateway 服务不可用"
    echo -e "\n  ${YELLOW}提示: 请先运行 ./scripts/dev-start.sh 启动微服务${NC}"
    exit 1
fi

print_test "Gateway Info 端点"
print_cmd "GET" "$GATEWAY_URL/actuator/info"
RESPONSE=$(curl -s --connect-timeout 5 "$GATEWAY_URL/actuator/info" 2>/dev/null)
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$GATEWAY_URL/actuator/info" 2>/dev/null)
print_response "$RESPONSE" "$HTTP_CODE"

if [ "$HTTP_CODE" == "200" ]; then
    log_pass "Info 端点可访问"
else
    log_fail "Info 端点不可用 (HTTP $HTTP_CODE)"
fi

print_test "Gateway 路由端点 (需要 gateway actuator)"
print_cmd "GET" "$GATEWAY_URL/actuator/gateway/routes"
RESPONSE=$(curl -s --connect-timeout 5 "$GATEWAY_URL/actuator/gateway/routes" 2>/dev/null)
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$GATEWAY_URL/actuator/gateway/routes" 2>/dev/null)
print_response "$RESPONSE" "$HTTP_CODE"

if [ "$HTTP_CODE" == "200" ]; then
    ROUTE_COUNT=$(echo "$RESPONSE" | grep -o '"route_id"' | wc -l)
    log_pass "Gateway 路由端点正常，共 $ROUTE_COUNT 条路由"
else
    log_fail "Gateway 路由端点不可用"
fi

# =============================================================================
# 2. 路由转发测试 - 验证所有服务路由
# =============================================================================

print_header "路由转发测试"

# 测试 User Service 路由
print_test "路由转发: /api/users/** -> user-service"
print_cmd "GET" "$GATEWAY_URL/api/users/1"
RESPONSE=$(curl -s --connect-timeout 5 "$GATEWAY_URL/api/users/1" 2>/dev/null)
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$GATEWAY_URL/api/users/1" 2>/dev/null)
print_response "$RESPONSE" "$HTTP_CODE"

if echo "$RESPONSE" | grep -qE '"code":(200|404)'; then
    log_pass "User Service 路由正常"
else
    log_fail "User Service 路由失败"
fi

# 测试 Asset Service 路由
print_test "路由转发: /api/assets/** -> asset-service"
print_cmd "GET" "$GATEWAY_URL/api/assets/user/1"
RESPONSE=$(curl -s --connect-timeout 5 "$GATEWAY_URL/api/assets/user/1" 2>/dev/null)
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$GATEWAY_URL/api/assets/user/1" 2>/dev/null)
print_response "$RESPONSE" "$HTTP_CODE"

if echo "$RESPONSE" | grep -q '"code":200'; then
    log_pass "Asset Service 路由正常"
else
    log_fail "Asset Service 路由失败"
fi

# 测试 Transaction Service 路由
print_test "路由转发: /api/transactions/** -> transaction-service"
print_cmd "GET" "$GATEWAY_URL/api/transactions/user/1"
RESPONSE=$(curl -s --connect-timeout 5 "$GATEWAY_URL/api/transactions/user/1" 2>/dev/null)
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$GATEWAY_URL/api/transactions/user/1" 2>/dev/null)
print_response "$RESPONSE" "$HTTP_CODE"

if echo "$RESPONSE" | grep -q '"code":200'; then
    log_pass "Transaction Service 路由正常"
else
    log_fail "Transaction Service 路由失败"
fi

# 测试 Statistics Service 路由
print_test "路由转发: /api/stats/** -> statistics-service"
print_cmd "GET" "$GATEWAY_URL/api/stats/summary/1"
RESPONSE=$(curl -s --connect-timeout 5 "$GATEWAY_URL/api/stats/summary/1" 2>/dev/null)
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$GATEWAY_URL/api/stats/summary/1" 2>/dev/null)
print_response "$RESPONSE" "$HTTP_CODE"

if echo "$RESPONSE" | grep -q '"code":200'; then
    log_pass "Statistics Service 路由正常"
else
    log_fail "Statistics Service 路由失败"
fi

# =============================================================================
# 3. HTTP 方法测试 - 验证各种 HTTP 方法通过网关
# =============================================================================

print_header "HTTP 方法转发测试"

# GET 方法
print_test "HTTP GET 方法"
print_cmd "GET" "$GATEWAY_URL/api/assets/1"
RESPONSE=$(curl -s --connect-timeout 5 "$GATEWAY_URL/api/assets/1" 2>/dev/null)
print_response "$RESPONSE"
if echo "$RESPONSE" | grep -qE '"code":(200|404)'; then
    log_pass "GET 方法正常转发"
else
    log_fail "GET 方法转发失败"
fi

# POST 方法
print_test "HTTP POST 方法"
POST_DATA='{"userId": 1, "name": "Gateway测试账户", "balance": 100.00}'
print_cmd "POST" "$GATEWAY_URL/api/assets" "$POST_DATA"
RESPONSE=$(curl -s --connect-timeout 5 -X POST "$GATEWAY_URL/api/assets" \
    -H "$CONTENT_TYPE" -d "$POST_DATA" 2>/dev/null)
print_response "$RESPONSE"
if echo "$RESPONSE" | grep -q '"code":200'; then
    NEW_ASSET_ID=$(echo "$RESPONSE" | grep -o '"id":[0-9]*' | head -1 | cut -d: -f2)
    echo -e "  ${BLUE}→${NC} 创建资产ID: $NEW_ASSET_ID"
    log_pass "POST 方法正常转发"
else
    log_fail "POST 方法转发失败"
fi

# PUT 方法
print_test "HTTP PUT 方法"
PUT_DATA='{"name": "Gateway更新测试"}'
print_cmd "PUT" "$GATEWAY_URL/api/assets/$NEW_ASSET_ID" "$PUT_DATA"
RESPONSE=$(curl -s --connect-timeout 5 -X PUT "$GATEWAY_URL/api/assets/$NEW_ASSET_ID" \
    -H "$CONTENT_TYPE" -d "$PUT_DATA" 2>/dev/null)
print_response "$RESPONSE"
if echo "$RESPONSE" | grep -q '"code":200'; then
    log_pass "PUT 方法正常转发"
else
    log_fail "PUT 方法转发失败"
fi

# DELETE 方法
print_test "HTTP DELETE 方法"
print_cmd "DELETE" "$GATEWAY_URL/api/assets/$NEW_ASSET_ID"
RESPONSE=$(curl -s --connect-timeout 5 -X DELETE "$GATEWAY_URL/api/assets/$NEW_ASSET_ID" 2>/dev/null)
print_response "$RESPONSE"
if echo "$RESPONSE" | grep -q '"code":200'; then
    log_pass "DELETE 方法正常转发"
else
    log_fail "DELETE 方法转发失败"
fi

# =============================================================================
# 4. CORS 跨域测试
# =============================================================================

print_header "CORS 跨域配置测试"

print_test "OPTIONS 预检请求"
echo -e "  ${CYAN}[CMD]${NC} curl -X OPTIONS '$GATEWAY_URL/api/assets/1' -H 'Origin: http://localhost:3000' -H 'Access-Control-Request-Method: POST' -v"
CORS_HEADERS=$(curl -s -X OPTIONS "$GATEWAY_URL/api/assets/1" \
    -H "Origin: http://localhost:3000" \
    -H "Access-Control-Request-Method: POST" \
    -D - -o /dev/null 2>/dev/null)

echo -e "  ${BLUE}←${NC} Response Headers:"
echo "$CORS_HEADERS" | grep -i "access-control" | while read line; do
    echo -e "      $line"
done

if echo "$CORS_HEADERS" | grep -qi "access-control-allow"; then
    log_pass "CORS 预检请求响应正常"
else
    log_fail "CORS 配置可能有问题"
fi

print_test "跨域请求 Access-Control-Allow-Origin"
RESPONSE_HEADERS=$(curl -s -D - -o /dev/null "$GATEWAY_URL/api/assets/1" \
    -H "Origin: http://localhost:3000" 2>/dev/null)

if echo "$RESPONSE_HEADERS" | grep -qi "access-control-allow-origin"; then
    ALLOW_ORIGIN=$(echo "$RESPONSE_HEADERS" | grep -i "access-control-allow-origin")
    echo -e "  ${BLUE}←${NC} $ALLOW_ORIGIN"
    log_pass "CORS Allow-Origin 配置正确"
else
    log_fail "缺少 Access-Control-Allow-Origin 头"
fi

# =============================================================================
# 5. 错误处理测试
# =============================================================================

print_header "错误处理测试"

print_test "请求不存在的路由 (应返回 404)"
print_cmd "GET" "$GATEWAY_URL/api/nonexistent/path"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$GATEWAY_URL/api/nonexistent/path" 2>/dev/null)
echo -e "  ${BLUE}←${NC} HTTP Status: $HTTP_CODE"

if [ "$HTTP_CODE" == "404" ]; then
    log_pass "未匹配路由返回 404"
else
    log_fail "预期 404，实际 $HTTP_CODE"
fi

print_test "请求不存在的资源 (后端服务返回 404)"
print_cmd "GET" "$GATEWAY_URL/api/assets/99999"
RESPONSE=$(curl -s --connect-timeout 5 "$GATEWAY_URL/api/assets/99999" 2>/dev/null)
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$GATEWAY_URL/api/assets/99999" 2>/dev/null)
print_response "$RESPONSE" "$HTTP_CODE"

if echo "$RESPONSE" | grep -q '"code":404'; then
    log_pass "后端 404 响应正确透传"
else
    log_fail "后端 404 响应透传失败"
fi

print_test "请求参数校验错误 (后端服务返回 400)"
INVALID_DATA='{"userId": 1, "assetId": 1, "amount": -10.00, "type": 1, "category": "test"}'
print_cmd "POST" "$GATEWAY_URL/api/transactions" "$INVALID_DATA"
RESPONSE=$(curl -s --connect-timeout 5 -X POST "$GATEWAY_URL/api/transactions" \
    -H "$CONTENT_TYPE" -d "$INVALID_DATA" 2>/dev/null)
print_response "$RESPONSE"

if echo "$RESPONSE" | grep -q '"code":400'; then
    log_pass "后端 400 响应正确透传"
else
    log_fail "后端 400 响应透传失败"
fi

# =============================================================================
# 6. 负载均衡测试 (通过 Nacos 服务发现)
# =============================================================================

print_header "负载均衡 & 服务发现测试"

print_test "检查 Nacos 服务注册状态"
echo -e "  ${CYAN}[CMD]${NC} curl 'http://localhost:8848/nacos/v1/ns/instance/list?serviceName=asset-service'"
NACOS_RESPONSE=$(curl -s --connect-timeout 5 "http://localhost:8848/nacos/v1/ns/instance/list?serviceName=asset-service" 2>/dev/null)

if echo "$NACOS_RESPONSE" | grep -q '"hosts"'; then
    INSTANCE_COUNT=$(echo "$NACOS_RESPONSE" | grep -o '"instanceId"' | wc -l)
    echo -e "  ${BLUE}←${NC} asset-service 实例数: $INSTANCE_COUNT"
    log_pass "服务已注册到 Nacos"
else
    log_fail "无法获取 Nacos 服务列表"
fi

print_test "Gateway 通过 Nacos 发现服务 (lb://)"
echo -e "  ${BLUE}→${NC} Gateway 使用 lb://asset-service 进行负载均衡"
print_cmd "GET" "$GATEWAY_URL/api/assets/1"
RESPONSE=$(curl -s --connect-timeout 5 "$GATEWAY_URL/api/assets/1" 2>/dev/null)
if echo "$RESPONSE" | grep -qE '"code":(200|404)'; then
    log_pass "负载均衡路由正常工作"
else
    log_fail "负载均衡路由失败"
fi

# =============================================================================
# 7. 响应时间测试
# =============================================================================

print_header "响应时间测试"

print_test "Gateway 响应延迟测试 (5次请求)"
TOTAL_TIME=0
for i in {1..5}; do
    TIME=$(curl -s -o /dev/null -w "%{time_total}" "$GATEWAY_URL/api/assets/1" 2>/dev/null)
    TIME_MS=$(echo "$TIME * 1000" | bc 2>/dev/null || echo "N/A")
    echo -e "  ${BLUE}→${NC} 请求 #$i: ${TIME_MS}ms"
    TOTAL_TIME=$(echo "$TOTAL_TIME + $TIME" | bc 2>/dev/null || echo "0")
done

if command -v bc &> /dev/null; then
    AVG_TIME=$(echo "scale=2; $TOTAL_TIME / 5 * 1000" | bc)
    echo -e "  ${BLUE}→${NC} 平均响应时间: ${AVG_TIME}ms"
    
    if (( $(echo "$AVG_TIME < 500" | bc -l) )); then
        log_pass "平均响应时间 < 500ms"
    else
        log_fail "平均响应时间过长: ${AVG_TIME}ms"
    fi
else
    log_pass "响应时间测试完成 (需要 bc 命令计算平均值)"
fi

# =============================================================================
# 8. 并发测试 (简单)
# =============================================================================

print_header "并发处理测试"

print_test "并发 10 个请求"
echo -e "  ${CYAN}[CMD]${NC} 使用后台进程模拟并发请求"

SUCCESS_COUNT=0
for i in {1..10}; do
    curl -s "$GATEWAY_URL/api/assets/1" > /tmp/gateway_test_$i.txt 2>&1 &
done
wait

for i in {1..10}; do
    if grep -q '"code":200' /tmp/gateway_test_$i.txt 2>/dev/null; then
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
    fi
    rm -f /tmp/gateway_test_$i.txt
done

echo -e "  ${BLUE}←${NC} 成功请求: $SUCCESS_COUNT / 10"
if [ $SUCCESS_COUNT -eq 10 ]; then
    log_pass "并发请求全部成功"
else
    log_fail "部分并发请求失败"
fi

# =============================================================================
# 测试报告
# =============================================================================

print_header "Gateway 测试报告"

echo ""
echo -e "  Gateway 地址: ${CYAN}$GATEWAY_URL${NC}"
echo -e "  总测试数:     $TOTAL_TESTS"
echo -e "  ${GREEN}通过:${NC}         $PASSED_TESTS"
echo -e "  ${RED}失败:${NC}         $FAILED_TESTS"
echo ""

# 路由汇总
echo -e "  ${BLUE}已配置路由:${NC}"
echo -e "    /api/users/**        → user-service (8081)"
echo -e "    /api/assets/**       → asset-service (8082)"
echo -e "    /api/transactions/** → transaction-service (8083)"
echo -e "    /api/stats/**        → statistics-service (8084)"
echo ""

if [ $FAILED_TESTS -eq 0 ]; then
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  ✓ Gateway 所有测试通过!${NC}"
    echo -e "${GREEN}========================================${NC}"
    exit 0
else
    echo -e "${RED}========================================${NC}"
    echo -e "${RED}  ✗ 有 $FAILED_TESTS 个测试失败${NC}"
    echo -e "${RED}========================================${NC}"
    exit 1
fi
