#!/bin/bash

# =============================================================================
# 个人记账系统 API 测试脚本
# =============================================================================

set -e

# 配置
BASE_URL="${BASE_URL:-http://localhost:8080}"
CONTENT_TYPE="Content-Type: application/json"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

print_request() {
    echo -e "  ${BLUE}→${NC} $1 $2"
    if [ -n "$3" ]; then
        echo -e "  ${BLUE}→${NC} Body: $3"
    fi
}

print_response() {
    echo -e "  ${BLUE}←${NC} Response: $1"
}

check_result() {
    local response="$1"
    local expected_code="$2"
    local test_name="$3"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    # 提取 code 字段
    local code=$(echo "$response" | jq -r '.code // empty' 2>/dev/null)
    
    if [ "$code" == "$expected_code" ]; then
        echo -e "  ${GREEN}✓ PASSED${NC} - code=$code"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        return 0
    else
        echo -e "  ${RED}✗ FAILED${NC} - Expected code=$expected_code, got code=$code"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        return 1
    fi
}

# =============================================================================
# 健康检查
# =============================================================================

print_header "服务健康检查"

print_test "检查服务是否运行..."
if curl -s --connect-timeout 5 "$BASE_URL/api/assets/user/1" > /dev/null 2>&1; then
    echo -e "  ${GREEN}✓${NC} 服务运行正常"
else
    echo -e "  ${RED}✗${NC} 无法连接到服务 $BASE_URL"
    echo -e "  ${YELLOW}提示: 请先运行 ./mvnw spring-boot:run 启动服务${NC}"
    exit 1
fi

# =============================================================================
# 资产管理 API 测试
# =============================================================================

print_header "资产管理 API 测试"

# 测试1: 查询用户资产列表
print_test "查询用户资产列表"
print_request "GET" "$BASE_URL/api/assets/user/1"
RESPONSE=$(curl -s "$BASE_URL/api/assets/user/1")
print_response "$RESPONSE"
check_result "$RESPONSE" "200" "查询用户资产列表"

# 测试2: 查询单个资产
print_test "查询单个资产详情"
print_request "GET" "$BASE_URL/api/assets/1"
RESPONSE=$(curl -s "$BASE_URL/api/assets/1")
print_response "$RESPONSE"
check_result "$RESPONSE" "200" "查询单个资产"

# 测试3: 查询不存在的资产
print_test "查询不存在的资产 (应返回404)"
print_request "GET" "$BASE_URL/api/assets/99999"
RESPONSE=$(curl -s "$BASE_URL/api/assets/99999")
print_response "$RESPONSE"
check_result "$RESPONSE" "404" "查询不存在的资产"

# 测试4: 创建新资产
print_test "创建新资产账户"
CREATE_ASSET_DATA='{"userId": 1, "name": "测试账户", "balance": 1000.00}'
print_request "POST" "$BASE_URL/api/assets" "$CREATE_ASSET_DATA"
RESPONSE=$(curl -s -X POST "$BASE_URL/api/assets" \
    -H "$CONTENT_TYPE" \
    -d "$CREATE_ASSET_DATA")
print_response "$RESPONSE"
check_result "$RESPONSE" "200" "创建新资产"

# 提取新创建的资产ID
NEW_ASSET_ID=$(echo "$RESPONSE" | jq -r '.data.id // empty' 2>/dev/null)
if [ -n "$NEW_ASSET_ID" ]; then
    echo -e "  ${BLUE}→${NC} 新资产ID: $NEW_ASSET_ID"
fi

# 测试5: 修改资产名称
print_test "修改资产名称 (PUT)"
UPDATE_ASSET_DATA='{"name": "私房钱"}'
print_request "PUT" "$BASE_URL/api/assets/$NEW_ASSET_ID" "$UPDATE_ASSET_DATA"
RESPONSE=$(curl -s -X PUT "$BASE_URL/api/assets/$NEW_ASSET_ID" \
    -H "$CONTENT_TYPE" \
    -d "$UPDATE_ASSET_DATA")
print_response "$RESPONSE"
check_result "$RESPONSE" "200" "修改资产名称"

# 验证名称已修改
RESPONSE=$(curl -s "$BASE_URL/api/assets/$NEW_ASSET_ID")
NEW_NAME=$(echo "$RESPONSE" | jq -r '.data.name // empty' 2>/dev/null)
echo -e "  ${BLUE}→${NC} 修改后名称: $NEW_NAME"

# =============================================================================
# 流水记账 API 测试
# =============================================================================

print_header "流水记账 API 测试"

# 测试6: 新增支出记录
print_test "新增支出记录 (type=1)"
EXPENSE_DATA='{"userId": 1, "assetId": 1, "amount": 50.00, "type": 1, "category": "餐饮"}'
print_request "POST" "$BASE_URL/api/transactions" "$EXPENSE_DATA"
RESPONSE=$(curl -s -X POST "$BASE_URL/api/transactions" \
    -H "$CONTENT_TYPE" \
    -d "$EXPENSE_DATA")
print_response "$RESPONSE"
check_result "$RESPONSE" "200" "新增支出记录"

# 提取流水ID用于后续删除测试
EXPENSE_ID=$(echo "$RESPONSE" | jq -r '.data.id // empty' 2>/dev/null)
echo -e "  ${BLUE}→${NC} 支出流水ID: $EXPENSE_ID"

# 测试7: 新增收入记录
print_test "新增收入记录 (type=2)"
INCOME_DATA='{"userId": 1, "assetId": 1, "amount": 200.00, "type": 2, "category": "工资"}'
print_request "POST" "$BASE_URL/api/transactions" "$INCOME_DATA"
RESPONSE=$(curl -s -X POST "$BASE_URL/api/transactions" \
    -H "$CONTENT_TYPE" \
    -d "$INCOME_DATA")
print_response "$RESPONSE"
check_result "$RESPONSE" "200" "新增收入记录"

INCOME_ID=$(echo "$RESPONSE" | jq -r '.data.id // empty' 2>/dev/null)
echo -e "  ${BLUE}→${NC} 收入流水ID: $INCOME_ID"

# 记录当前余额
RESPONSE=$(curl -s "$BASE_URL/api/assets/1")
BALANCE_BEFORE=$(echo "$RESPONSE" | jq -r '.data.balance // empty' 2>/dev/null)
echo -e "  ${BLUE}→${NC} 当前余额: $BALANCE_BEFORE"

# 测试8: 查询用户流水列表
print_test "查询用户流水列表"
print_request "GET" "$BASE_URL/api/transactions/user/1"
RESPONSE=$(curl -s "$BASE_URL/api/transactions/user/1")
print_response "$RESPONSE"
check_result "$RESPONSE" "200" "查询用户流水列表"

# =============================================================================
# 流水删除与余额回滚测试 (核心功能)
# =============================================================================

print_header "流水删除与余额回滚测试"

# 测试9: 删除支出记录 (余额应增加)
print_test "删除支出记录 (余额应回滚增加 +50)"
print_request "DELETE" "$BASE_URL/api/transactions/$EXPENSE_ID"
RESPONSE=$(curl -s -X DELETE "$BASE_URL/api/transactions/$EXPENSE_ID")
print_response "$RESPONSE"
check_result "$RESPONSE" "200" "删除支出记录"

# 验证余额回滚
RESPONSE=$(curl -s "$BASE_URL/api/assets/1")
BALANCE_AFTER=$(echo "$RESPONSE" | jq -r '.data.balance // empty' 2>/dev/null)
echo -e "  ${BLUE}→${NC} 删除支出后余额: $BALANCE_AFTER (预期增加50)"

# 测试10: 删除收入记录 (余额应减少)
print_test "删除收入记录 (余额应回滚减少 -200)"
print_request "DELETE" "$BASE_URL/api/transactions/$INCOME_ID"
RESPONSE=$(curl -s -X DELETE "$BASE_URL/api/transactions/$INCOME_ID")
print_response "$RESPONSE"
check_result "$RESPONSE" "200" "删除收入记录"

# 验证余额回滚
RESPONSE=$(curl -s "$BASE_URL/api/assets/1")
BALANCE_FINAL=$(echo "$RESPONSE" | jq -r '.data.balance // empty' 2>/dev/null)
echo -e "  ${BLUE}→${NC} 删除收入后余额: $BALANCE_FINAL (预期减少200)"

# 测试11: 删除不存在的流水
print_test "删除不存在的流水 (应返回404)"
print_request "DELETE" "$BASE_URL/api/transactions/99999"
RESPONSE=$(curl -s -X DELETE "$BASE_URL/api/transactions/99999")
print_response "$RESPONSE"
check_result "$RESPONSE" "404" "删除不存在的流水"

# =============================================================================
# 资产删除测试
# =============================================================================

print_header "资产删除测试"

# 测试12: 删除有流水记录的资产 (应被拒绝)
print_test "删除有流水的资产 (应返回500业务错误)"
print_request "DELETE" "$BASE_URL/api/assets/1"
RESPONSE=$(curl -s -X DELETE "$BASE_URL/api/assets/1")
print_response "$RESPONSE"
check_result "$RESPONSE" "500" "删除有流水的资产"

# 测试13: 删除没有流水的资产 (应成功)
print_test "删除无流水的资产 (应成功)"
print_request "DELETE" "$BASE_URL/api/assets/$NEW_ASSET_ID"
RESPONSE=$(curl -s -X DELETE "$BASE_URL/api/assets/$NEW_ASSET_ID")
print_response "$RESPONSE"
check_result "$RESPONSE" "200" "删除无流水的资产"

# =============================================================================
# 参数校验测试
# =============================================================================

print_header "参数校验测试"

# 测试14: 金额为负数
print_test "金额为负数 (应返回400)"
INVALID_AMOUNT='{"userId": 1, "assetId": 1, "amount": -10.00, "type": 1, "category": "测试"}'
print_request "POST" "$BASE_URL/api/transactions" "$INVALID_AMOUNT"
RESPONSE=$(curl -s -X POST "$BASE_URL/api/transactions" \
    -H "$CONTENT_TYPE" \
    -d "$INVALID_AMOUNT")
print_response "$RESPONSE"
check_result "$RESPONSE" "400" "金额为负数"

# 测试15: 类型无效
print_test "交易类型无效 (应返回业务错误)"
INVALID_TYPE='{"userId": 1, "assetId": 1, "amount": 10.00, "type": 3, "category": "测试"}'
print_request "POST" "$BASE_URL/api/transactions" "$INVALID_TYPE"
RESPONSE=$(curl -s -X POST "$BASE_URL/api/transactions" \
    -H "$CONTENT_TYPE" \
    -d "$INVALID_TYPE")
print_response "$RESPONSE"
CODE=$(echo "$RESPONSE" | jq -r '.code // empty' 2>/dev/null)
TOTAL_TESTS=$((TOTAL_TESTS + 1))
if [ "$CODE" != "200" ]; then
    echo -e "  ${GREEN}✓ PASSED${NC} - 业务校验生效 (code=$CODE)"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "  ${RED}✗ FAILED${NC} - 应该返回错误"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi

# 测试16: 资产不存在
print_test "资产不存在 (应返回404)"
INVALID_ASSET='{"userId": 1, "assetId": 99999, "amount": 10.00, "type": 1, "category": "测试"}'
print_request "POST" "$BASE_URL/api/transactions" "$INVALID_ASSET"
RESPONSE=$(curl -s -X POST "$BASE_URL/api/transactions" \
    -H "$CONTENT_TYPE" \
    -d "$INVALID_ASSET")
print_response "$RESPONSE"
check_result "$RESPONSE" "404" "资产不存在"

# =============================================================================
# 测试报告
# =============================================================================

print_header "测试报告"

echo ""
echo -e "  总测试数:   $TOTAL_TESTS"
echo -e "  ${GREEN}通过:${NC}       $PASSED_TESTS"
echo -e "  ${RED}失败:${NC}       $FAILED_TESTS"
echo ""

if [ $FAILED_TESTS -eq 0 ]; then
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  ✓ 所有测试通过!${NC}"
    echo -e "${GREEN}========================================${NC}"
    exit 0
else
    echo -e "${RED}========================================${NC}"
    echo -e "${RED}  ✗ 有 $FAILED_TESTS 个测试失败${NC}"
    echo -e "${RED}========================================${NC}"
    exit 1
fi
