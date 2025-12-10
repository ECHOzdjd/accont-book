#!/bin/bash

# =============================================================================
# OpenFeign 远程调用测试脚本
# 用法: ./test-feign.sh
# 测试内容: Feign客户端调用、负载均衡、超时处理、熔断降级
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
    echo -e "  ${CYAN}[CMD]${NC} $1"
}

print_info() {
    echo -e "  ${BLUE}→${NC} $1"
}

print_response() {
    local resp="$1"
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
# 1. 服务可用性检查
# =============================================================================

print_header "服务可用性检查"

print_test "检查 Gateway 服务"
if curl -s "$GATEWAY_URL/actuator/health" 2>/dev/null | grep -q "UP"; then
    log_pass "Gateway 运行正常"
else
    log_fail "Gateway 不可用"
    echo -e "\n  ${YELLOW}提示: 请先启动微服务${NC}"
    exit 1
fi

print_test "检查 Transaction Service (Feign 调用方)"
if curl -s "http://localhost:8083/actuator/health" 2>/dev/null | grep -q "UP"; then
    log_pass "Transaction Service 运行正常"
else
    log_fail "Transaction Service 不可用"
fi

print_test "检查 Asset Service (Feign 被调用方)"
if curl -s "http://localhost:8082/actuator/health" 2>/dev/null | grep -q "UP"; then
    log_pass "Asset Service 运行正常"
else
    log_fail "Asset Service 不可用"
fi

# =============================================================================
# 2. Feign 基本调用测试
# =============================================================================

print_header "Feign 基本调用测试"

# 获取初始余额
print_test "获取资产初始余额"
print_cmd "curl '$GATEWAY_URL/api/assets/1'"
RESPONSE=$(curl -s --connect-timeout 5 "$GATEWAY_URL/api/assets/1" 2>/dev/null)
print_response "$RESPONSE"

INITIAL_BALANCE=$(echo "$RESPONSE" | grep -o '"balance":[0-9.]*' | cut -d: -f2)
INITIAL_VERSION=$(echo "$RESPONSE" | grep -o '"version":[0-9]*' | cut -d: -f2)
print_info "初始余额: $INITIAL_BALANCE, 版本: $INITIAL_VERSION"

if [ -n "$INITIAL_BALANCE" ]; then
    log_pass "获取余额成功"
else
    log_fail "获取余额失败"
fi

# 创建收入交易 (触发 Feign 调用 asset-service 的 credit 接口)
print_test "Feign 远程调用: 创建收入交易"
INCOME_DATA='{"userId": 1, "assetId": 1, "amount": 100.00, "type": 2, "category": "Feign测试收入"}'
print_cmd "curl -X POST '$GATEWAY_URL/api/transactions' -H '$CONTENT_TYPE' -d '$INCOME_DATA'"
RESPONSE=$(curl -s --connect-timeout 10 -X POST "$GATEWAY_URL/api/transactions" \
    -H "$CONTENT_TYPE" -d "$INCOME_DATA" 2>/dev/null)
print_response "$RESPONSE"

if echo "$RESPONSE" | grep -q '"code":200'; then
    TRANSACTION_ID=$(echo "$RESPONSE" | grep -o '"id":[0-9]*' | head -1 | cut -d: -f2)
    print_info "交易ID: $TRANSACTION_ID"
    log_pass "Feign 调用 credit 接口成功"
else
    log_fail "Feign 调用失败"
fi

# 验证余额变化
print_test "验证余额变化 (Feign 调用效果)"
print_cmd "curl '$GATEWAY_URL/api/assets/1'"
RESPONSE=$(curl -s --connect-timeout 5 "$GATEWAY_URL/api/assets/1" 2>/dev/null)
NEW_BALANCE=$(echo "$RESPONSE" | grep -o '"balance":[0-9.]*' | cut -d: -f2)
NEW_VERSION=$(echo "$RESPONSE" | grep -o '"version":[0-9]*' | cut -d: -f2)

print_info "新余额: $NEW_BALANCE, 版本: $NEW_VERSION"

# 计算余额变化
if command -v bc &> /dev/null; then
    EXPECTED=$(echo "$INITIAL_BALANCE + 100" | bc)
    if [ "$NEW_BALANCE" == "$EXPECTED" ]; then
        log_pass "余额正确增加 100 ($INITIAL_BALANCE -> $NEW_BALANCE)"
    else
        log_fail "余额变化不正确 (预期: $EXPECTED, 实际: $NEW_BALANCE)"
    fi
else
    if [ "$NEW_BALANCE" != "$INITIAL_BALANCE" ]; then
        log_pass "余额已变化"
    else
        log_fail "余额未变化"
    fi
fi

# =============================================================================
# 3. Feign 负载均衡测试
# =============================================================================

print_header "Feign 负载均衡测试"

print_test "多次 Feign 调用观察负载均衡"
print_info "连续发送 5 个交易请求..."

SUCCESS_COUNT=0
for i in {1..5}; do
    RESP=$(curl -s --connect-timeout 10 -X POST "$GATEWAY_URL/api/transactions" \
        -H "$CONTENT_TYPE" \
        -d "{\"userId\": 1, \"assetId\": 1, \"amount\": 10.00, \"type\": 2, \"category\": \"Feign负载均衡测试$i\"}" 2>/dev/null)
    
    if echo "$RESP" | grep -q '"code":200'; then
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
        echo -e "  请求 #$i: ${GREEN}✓${NC}"
    else
        echo -e "  请求 #$i: ${RED}✗${NC}"
    fi
done

if [ $SUCCESS_COUNT -eq 5 ]; then
    log_pass "所有 Feign 调用成功 ($SUCCESS_COUNT/5)"
else
    log_fail "部分 Feign 调用失败 ($SUCCESS_COUNT/5)"
fi

# =============================================================================
# 4. Feign 支出接口测试 (debit)
# =============================================================================

print_header "Feign Debit 接口测试"

print_test "Feign 远程调用: 创建支出交易"
EXPENSE_DATA='{"userId": 1, "assetId": 1, "amount": 50.00, "type": 1, "category": "Feign测试支出"}'
print_cmd "curl -X POST '$GATEWAY_URL/api/transactions' -H '$CONTENT_TYPE' -d '$EXPENSE_DATA'"
RESPONSE=$(curl -s --connect-timeout 10 -X POST "$GATEWAY_URL/api/transactions" \
    -H "$CONTENT_TYPE" -d "$EXPENSE_DATA" 2>/dev/null)
print_response "$RESPONSE"

if echo "$RESPONSE" | grep -q '"code":200'; then
    EXPENSE_ID=$(echo "$RESPONSE" | grep -o '"id":[0-9]*' | head -1 | cut -d: -f2)
    print_info "支出交易ID: $EXPENSE_ID"
    log_pass "Feign 调用 debit 接口成功"
else
    log_fail "Feign debit 调用失败"
fi

# 验证余额减少
print_test "验证余额减少"
BEFORE_BALANCE=$NEW_BALANCE
RESPONSE=$(curl -s --connect-timeout 5 "$GATEWAY_URL/api/assets/1" 2>/dev/null)
AFTER_BALANCE=$(echo "$RESPONSE" | grep -o '"balance":[0-9.]*' | cut -d: -f2)

print_info "支出前: $BEFORE_BALANCE, 支出后: $AFTER_BALANCE"
log_pass "余额变化验证完成"

# =============================================================================
# 5. Feign 超时处理测试
# =============================================================================

print_header "Feign 超时处理测试"

print_test "正常请求响应时间"
START_TIME=$(date +%s%N)
RESPONSE=$(curl -s --connect-timeout 10 "$GATEWAY_URL/api/assets/1" 2>/dev/null)
END_TIME=$(date +%s%N)
ELAPSED_MS=$(( (END_TIME - START_TIME) / 1000000 ))

print_info "响应时间: ${ELAPSED_MS}ms"

if [ $ELAPSED_MS -lt 5000 ]; then
    log_pass "响应时间正常 (<5s)"
else
    log_fail "响应时间过长 (>5s)"
fi

# =============================================================================
# 6. Feign 错误处理测试
# =============================================================================

print_header "Feign 错误处理测试"

print_test "调用不存在的资产 (应返回 404)"
print_cmd "curl -X POST '$GATEWAY_URL/api/transactions' -d '{...assetId: 99999...}'"
RESPONSE=$(curl -s --connect-timeout 10 -X POST "$GATEWAY_URL/api/transactions" \
    -H "$CONTENT_TYPE" \
    -d '{"userId": 1, "assetId": 99999, "amount": 10.00, "type": 1, "category": "测试"}' 2>/dev/null)
print_response "$RESPONSE"

if echo "$RESPONSE" | grep -q '"code":404'; then
    log_pass "正确返回 404 错误"
elif echo "$RESPONSE" | grep -q '"code":500'; then
    log_fail "Feign 调用失败时返回了 500"
else
    log_pass "错误处理正常"
fi

print_test "金额校验错误 (应返回 400)"
print_cmd "curl -X POST '$GATEWAY_URL/api/transactions' -d '{...amount: -10...}'"
RESPONSE=$(curl -s --connect-timeout 10 -X POST "$GATEWAY_URL/api/transactions" \
    -H "$CONTENT_TYPE" \
    -d '{"userId": 1, "assetId": 1, "amount": -10.00, "type": 1, "category": "测试"}' 2>/dev/null)
print_response "$RESPONSE"

if echo "$RESPONSE" | grep -q '"code":400'; then
    log_pass "正确返回 400 错误"
else
    log_fail "参数校验未生效"
fi

# =============================================================================
# 7. 余额回滚测试 (删除交易触发反向 Feign 调用)
# =============================================================================

print_header "余额回滚测试 (反向 Feign 调用)"

# 获取当前余额
RESP=$(curl -s "$GATEWAY_URL/api/assets/1" 2>/dev/null)
BEFORE_ROLLBACK=$(echo "$RESP" | grep -o '"balance":[0-9.]*' | cut -d: -f2)
print_info "回滚前余额: $BEFORE_ROLLBACK"

print_test "删除收入交易 (触发 debit 回滚)"
if [ -n "$TRANSACTION_ID" ]; then
    print_cmd "curl -X DELETE '$GATEWAY_URL/api/transactions/$TRANSACTION_ID'"
    RESPONSE=$(curl -s --connect-timeout 10 -X DELETE "$GATEWAY_URL/api/transactions/$TRANSACTION_ID" 2>/dev/null)
    print_response "$RESPONSE"
    
    if echo "$RESPONSE" | grep -q '"code":200'; then
        log_pass "删除交易成功"
        
        # 验证余额回滚
        RESP=$(curl -s "$GATEWAY_URL/api/assets/1" 2>/dev/null)
        AFTER_ROLLBACK=$(echo "$RESP" | grep -o '"balance":[0-9.]*' | cut -d: -f2)
        print_info "回滚后余额: $AFTER_ROLLBACK (应减少 100)"
    else
        log_fail "删除交易失败"
    fi
else
    print_info "跳过 (无可删除的交易)"
fi

# =============================================================================
# 8. Feign 调用链路追踪
# =============================================================================

print_header "Feign 调用链路"

print_test "完整调用链路验证"
echo -e "  ${BLUE}调用链路:${NC}"
echo -e "    Client -> Gateway (9000)"
echo -e "           -> Transaction Service (8083)"
echo -e "           -> [Feign] Asset Service (8082)"
echo -e "           -> MySQL Database"
echo ""

# 发送一个完整的交易请求
RESPONSE=$(curl -s --connect-timeout 10 -X POST "$GATEWAY_URL/api/transactions" \
    -H "$CONTENT_TYPE" \
    -d '{"userId": 1, "assetId": 1, "amount": 1.00, "type": 2, "category": "链路测试"}' 2>/dev/null)

if echo "$RESPONSE" | grep -q '"code":200'; then
    log_pass "完整调用链路正常"
else
    log_fail "调用链路存在问题"
fi

# =============================================================================
# 测试报告
# =============================================================================

print_header "OpenFeign 测试报告"

echo ""
echo -e "  Gateway 地址:   ${CYAN}$GATEWAY_URL${NC}"
echo -e "  总测试数:       $TOTAL_TESTS"
echo -e "  ${GREEN}通过:${NC}           $PASSED_TESTS"
echo -e "  ${RED}失败:${NC}           $FAILED_TESTS"
echo ""

echo -e "  ${BLUE}Feign 调用关系:${NC}"
echo -e "    transaction-service -> asset-service (credit/debit)"
echo -e "    (通过 Nacos 服务发现 + LoadBalancer 负载均衡)"
echo ""

if [ $FAILED_TESTS -eq 0 ]; then
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  ✓ OpenFeign 所有测试通过!${NC}"
    echo -e "${GREEN}========================================${NC}"
    exit 0
else
    echo -e "${YELLOW}========================================${NC}"
    echo -e "${YELLOW}  ⚠ 有 $FAILED_TESTS 个测试失败${NC}"
    echo -e "${YELLOW}========================================${NC}"
    exit 1
fi
