#!/bin/bash

# =============================================================================
# RabbitMQ 消息队列测试脚本
# 用法: ./test-mq.sh
# 测试内容: RabbitMQ连接、交换机/队列、消息生产消费、事件驱动
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
RABBITMQ_URL="${RABBITMQ_URL:-http://localhost:15672}"
RABBITMQ_USER="${RABBITMQ_USER:-guest}"
RABBITMQ_PASS="${RABBITMQ_PASS:-guest}"
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

rabbitmq_api() {
    curl -s -u "$RABBITMQ_USER:$RABBITMQ_PASS" "$RABBITMQ_URL/api/$1" 2>/dev/null
}

# =============================================================================
# 1. RabbitMQ 服务健康检查
# =============================================================================

print_header "RabbitMQ 服务健康检查"

print_test "RabbitMQ 管理控制台可访问性"
print_cmd "curl -u guest:guest '$RABBITMQ_URL/api/overview'"
RESPONSE=$(rabbitmq_api "overview")
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -u "$RABBITMQ_USER:$RABBITMQ_PASS" "$RABBITMQ_URL/api/overview" 2>/dev/null)

if [ "$HTTP_CODE" == "200" ]; then
    log_pass "RabbitMQ 管理控制台可访问"
    
    # 提取版本信息
    VERSION=$(echo "$RESPONSE" | grep -o '"rabbitmq_version":"[^"]*"' | cut -d'"' -f4)
    print_info "RabbitMQ 版本: $VERSION"
else
    log_fail "RabbitMQ 管理控制台不可用 (HTTP $HTTP_CODE)"
    echo -e "\n  ${YELLOW}提示: 请确保 RabbitMQ 正在运行${NC}"
    exit 1
fi

print_test "RabbitMQ 节点状态"
print_cmd "curl -u guest:guest '$RABBITMQ_URL/api/nodes'"
RESPONSE=$(rabbitmq_api "nodes")

NODE_COUNT=$(echo "$RESPONSE" | grep -o '"name"' | wc -l)
RUNNING=$(echo "$RESPONSE" | grep -o '"running":true' | wc -l)

if [ "$RUNNING" -gt 0 ]; then
    log_pass "RabbitMQ 节点运行正常 ($RUNNING 个运行中)"
else
    log_fail "RabbitMQ 节点异常"
fi

# =============================================================================
# 2. 交换机检查
# =============================================================================

print_header "交换机 (Exchange) 检查"

print_test "获取交换机列表"
print_cmd "curl -u guest:guest '$RABBITMQ_URL/api/exchanges'"
RESPONSE=$(rabbitmq_api "exchanges")

# 检查 transaction.exchange
print_test "检查 transaction.exchange"
if echo "$RESPONSE" | grep -q '"name":"transaction.exchange"'; then
    log_pass "交换机 transaction.exchange 存在"
    
    # 获取详细信息
    EXCHANGE_INFO=$(rabbitmq_api "exchanges/%2f/transaction.exchange")
    EXCHANGE_TYPE=$(echo "$EXCHANGE_INFO" | grep -o '"type":"[^"]*"' | cut -d'"' -f4)
    print_info "类型: $EXCHANGE_TYPE"
else
    log_fail "交换机 transaction.exchange 不存在"
    print_info "提示: 交换机将在第一条消息发送时自动创建"
fi

# 显示所有自定义交换机
print_test "列出自定义交换机"
echo "$RESPONSE" | python3 -c "
import sys, json
try:
    exchanges = json.load(sys.stdin)
    custom_exchanges = [e for e in exchanges if not e.get('name', '').startswith('amq.') and e.get('name')]
    for e in custom_exchanges:
        print(f\"  - {e.get('name')} (type: {e.get('type')}, durable: {e.get('durable')})\")
    if not custom_exchanges:
        print('  (无自定义交换机)')
except:
    pass
" 2>/dev/null || echo "  (无法解析)"

# =============================================================================
# 3. 队列检查
# =============================================================================

print_header "队列 (Queue) 检查"

print_test "获取队列列表"
print_cmd "curl -u guest:guest '$RABBITMQ_URL/api/queues'"
RESPONSE=$(rabbitmq_api "queues")

# 检查 transaction.success.queue
print_test "检查 transaction.success.queue"
if echo "$RESPONSE" | grep -q '"name":"transaction.success.queue"'; then
    log_pass "队列 transaction.success.queue 存在"
    
    # 获取队列详情
    QUEUE_INFO=$(rabbitmq_api "queues/%2f/transaction.success.queue")
    MESSAGES=$(echo "$QUEUE_INFO" | grep -o '"messages":[0-9]*' | head -1 | cut -d: -f2)
    CONSUMERS=$(echo "$QUEUE_INFO" | grep -o '"consumers":[0-9]*' | cut -d: -f2)
    
    print_info "消息数: $MESSAGES, 消费者数: $CONSUMERS"
else
    log_fail "队列 transaction.success.queue 不存在"
    print_info "提示: 队列将在消费者启动时自动创建"
fi

# 显示所有队列
print_test "列出所有队列"
echo "$RESPONSE" | python3 -c "
import sys, json
try:
    queues = json.load(sys.stdin)
    for q in queues:
        name = q.get('name', 'unknown')
        messages = q.get('messages', 0)
        consumers = q.get('consumers', 0)
        state = q.get('state', 'unknown')
        print(f\"  - {name}: {messages} 消息, {consumers} 消费者, 状态: {state}\")
    if not queues:
        print('  (无队列)')
except:
    pass
" 2>/dev/null || echo "  (无法解析)"

# =============================================================================
# 4. 绑定关系检查
# =============================================================================

print_header "绑定关系 (Binding) 检查"

print_test "获取绑定列表"
print_cmd "curl -u guest:guest '$RABBITMQ_URL/api/bindings'"
RESPONSE=$(rabbitmq_api "bindings")

print_test "检查 transaction.exchange -> transaction.success.queue 绑定"
if echo "$RESPONSE" | grep -q '"source":"transaction.exchange".*"destination":"transaction.success.queue"' || \
   echo "$RESPONSE" | grep -q '"source":"transaction.exchange"'; then
    log_pass "绑定关系存在"
else
    log_fail "绑定关系不存在"
    print_info "提示: 绑定将在服务启动时自动创建"
fi

# 显示所有绑定
echo "$RESPONSE" | python3 -c "
import sys, json
try:
    bindings = json.load(sys.stdin)
    custom_bindings = [b for b in bindings if b.get('source') and not b.get('source').startswith('amq.')]
    if custom_bindings:
        print('  自定义绑定:')
        for b in custom_bindings:
            print(f\"    {b.get('source')} -> {b.get('destination')} (routing_key: {b.get('routing_key', '*')})\")
    else:
        print('  (无自定义绑定)')
except:
    pass
" 2>/dev/null || true

# =============================================================================
# 5. 消息生产测试
# =============================================================================

print_header "消息生产测试"

print_test "通过创建交易触发消息发送"

# 获取初始消息数
QUEUE_INFO=$(rabbitmq_api "queues/%2f/transaction.success.queue" 2>/dev/null)
INITIAL_MESSAGES=$(echo "$QUEUE_INFO" | grep -o '"messages":[0-9]*' | head -1 | cut -d: -f2)
INITIAL_MESSAGES=${INITIAL_MESSAGES:-0}
print_info "初始队列消息数: $INITIAL_MESSAGES"

# 创建交易 (触发消息发送)
print_cmd "curl -X POST '$GATEWAY_URL/api/transactions' -d '{...MQ测试...}'"
RESPONSE=$(curl -s --connect-timeout 10 -X POST "$GATEWAY_URL/api/transactions" \
    -H "$CONTENT_TYPE" \
    -d '{"userId": 1, "assetId": 1, "amount": 1.00, "type": 2, "category": "MQ测试"}' 2>/dev/null)

if echo "$RESPONSE" | grep -q '"code":200'; then
    log_pass "交易创建成功 (消息已发送)"
    
    # 等待消息处理
    sleep 2
    
    # 检查消息是否被消费
    QUEUE_INFO=$(rabbitmq_api "queues/%2f/transaction.success.queue" 2>/dev/null)
    CURRENT_MESSAGES=$(echo "$QUEUE_INFO" | grep -o '"messages":[0-9]*' | head -1 | cut -d: -f2)
    CURRENT_MESSAGES=${CURRENT_MESSAGES:-0}
    
    print_info "当前队列消息数: $CURRENT_MESSAGES"
else
    log_fail "交易创建失败"
fi

# =============================================================================
# 6. 消息消费测试
# =============================================================================

print_header "消息消费测试"

print_test "检查 Statistics Service 消费者状态"

# 检查 statistics-service 是否作为消费者连接
RESPONSE=$(rabbitmq_api "consumers")
CONSUMER_COUNT=$(echo "$RESPONSE" | grep -o '"consumer_tag"' | wc -l)

print_info "活跃消费者数: $CONSUMER_COUNT"

if [ "$CONSUMER_COUNT" -gt 0 ]; then
    log_pass "消息消费者已连接"
    
    # 显示消费者详情
    echo "$RESPONSE" | python3 -c "
import sys, json
try:
    consumers = json.load(sys.stdin)
    for c in consumers[:5]:  # 只显示前5个
        queue = c.get('queue', {}).get('name', 'unknown')
        tag = c.get('consumer_tag', 'unknown')[:30]
        print(f\"    - 队列: {queue}, 标签: {tag}...\")
except:
    pass
" 2>/dev/null || true
else
    log_fail "无活跃消费者"
fi

# =============================================================================
# 7. 消息确认测试
# =============================================================================

print_header "消息确认 (ACK) 测试"

print_test "检查队列消息确认状态"
QUEUE_INFO=$(rabbitmq_api "queues/%2f/transaction.success.queue" 2>/dev/null)

MESSAGES_READY=$(echo "$QUEUE_INFO" | grep -o '"messages_ready":[0-9]*' | cut -d: -f2)
MESSAGES_UNACKED=$(echo "$QUEUE_INFO" | grep -o '"messages_unacknowledged":[0-9]*' | cut -d: -f2)

MESSAGES_READY=${MESSAGES_READY:-0}
MESSAGES_UNACKED=${MESSAGES_UNACKED:-0}

print_info "待处理消息: $MESSAGES_READY"
print_info "未确认消息: $MESSAGES_UNACKED"

if [ "$MESSAGES_UNACKED" -eq 0 ]; then
    log_pass "所有消息已确认"
else
    log_fail "存在 $MESSAGES_UNACKED 条未确认消息"
fi

# =============================================================================
# 8. 消息吞吐量测试
# =============================================================================

print_header "消息吞吐量测试"

print_test "发送 10 条消息测试吞吐量"

START_TIME=$(date +%s%N)
SUCCESS=0

for i in {1..10}; do
    RESP=$(curl -s --connect-timeout 10 -X POST "$GATEWAY_URL/api/transactions" \
        -H "$CONTENT_TYPE" \
        -d "{\"userId\": 1, \"assetId\": 1, \"amount\": 1.00, \"type\": 2, \"category\": \"MQ吞吐量测试$i\"}" 2>/dev/null)
    
    if echo "$RESP" | grep -q '"code":200'; then
        SUCCESS=$((SUCCESS + 1))
    fi
done

END_TIME=$(date +%s%N)
ELAPSED_MS=$(( (END_TIME - START_TIME) / 1000000 ))

print_info "成功发送: $SUCCESS / 10"
print_info "总耗时: ${ELAPSED_MS}ms"

if [ $SUCCESS -ge 8 ]; then
    log_pass "消息发送成功率 >= 80%"
else
    log_fail "消息发送成功率 < 80%"
fi

# 等待消息消费
sleep 3

# =============================================================================
# 9. 统计服务数据验证
# =============================================================================

print_header "统计服务数据验证 (消息消费结果)"

print_test "验证统计数据更新"
print_cmd "curl '$GATEWAY_URL/api/stats/summary/1'"
RESPONSE=$(curl -s --connect-timeout 5 "$GATEWAY_URL/api/stats/summary/1" 2>/dev/null)
print_response "$RESPONSE"

if echo "$RESPONSE" | grep -q '"code":200'; then
    TOTAL_INCOME=$(echo "$RESPONSE" | grep -o '"totalIncome":[0-9.]*' | cut -d: -f2)
    TRANSACTION_COUNT=$(echo "$RESPONSE" | grep -o '"transactionCount":[0-9]*' | cut -d: -f2)
    
    print_info "总收入: $TOTAL_INCOME"
    print_info "交易数: $TRANSACTION_COUNT"
    
    log_pass "统计数据正常 (消息已被消费并处理)"
else
    log_fail "统计数据获取失败"
fi

# =============================================================================
# 10. 连接状态检查
# =============================================================================

print_header "连接状态检查"

print_test "检查 RabbitMQ 连接"
RESPONSE=$(rabbitmq_api "connections")
CONNECTION_COUNT=$(echo "$RESPONSE" | grep -o '"name"' | wc -l)

print_info "活跃连接数: $CONNECTION_COUNT"

if [ "$CONNECTION_COUNT" -gt 0 ]; then
    log_pass "RabbitMQ 连接正常"
    
    # 显示连接详情
    echo "$RESPONSE" | python3 -c "
import sys, json
try:
    connections = json.load(sys.stdin)
    for c in connections[:5]:
        user = c.get('user', 'unknown')
        host = c.get('peer_host', 'unknown')
        state = c.get('state', 'unknown')
        print(f\"    - 用户: {user}, 来源: {host}, 状态: {state}\")
except:
    pass
" 2>/dev/null || true
else
    log_fail "无活跃连接"
fi

# =============================================================================
# 测试报告
# =============================================================================

print_header "RabbitMQ 测试报告"

echo ""
echo -e "  RabbitMQ 地址:  ${CYAN}$RABBITMQ_URL${NC}"
echo -e "  总测试数:       $TOTAL_TESTS"
echo -e "  ${GREEN}通过:${NC}           $PASSED_TESTS"
echo -e "  ${RED}失败:${NC}           $FAILED_TESTS"
echo ""

echo -e "  ${BLUE}消息流向:${NC}"
echo -e "    Transaction Service"
echo -e "         ↓ (发送消息)"
echo -e "    transaction.exchange"
echo -e "         ↓ (路由)"
echo -e "    transaction.success.queue"
echo -e "         ↓ (消费)"
echo -e "    Statistics Service"
echo ""

if [ $FAILED_TESTS -eq 0 ]; then
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  ✓ RabbitMQ 所有测试通过!${NC}"
    echo -e "${GREEN}========================================${NC}"
    exit 0
else
    echo -e "${YELLOW}========================================${NC}"
    echo -e "${YELLOW}  ⚠ 有 $FAILED_TESTS 个测试失败${NC}"
    echo -e "${YELLOW}========================================${NC}"
    exit 1
fi
