#!/bin/bash
# ============================================================
# Sentinel 熔断恢复演示脚本
# ============================================================

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

TRANSACTION_URL="http://localhost:8083"

echo -e "${BLUE}===== Sentinel 熔断恢复机制演示 =====${NC}"
echo ""
echo "这个脚本会展示熔断的完整生命周期："
echo "  1. 正常请求 → 2. 触发熔断 → 3. 熔断中 → 4. 恢复"
echo ""

# 阶段1: 正常请求
echo -e "${GREEN}[阶段1] 发送正常请求（快速）${NC}"
for i in {1..5}; do
    result=$(curl -s -o /dev/null -w "%{http_code}" "$TRANSACTION_URL/api/test/slow?delay=10")
    echo "  请求 $i: HTTP $result ✓"
    sleep 0.3
done

echo ""
echo -e "${YELLOW}[阶段2] 发送慢请求触发熔断${NC}"
echo "发送 5 个慢请求（100ms），触发熔断规则..."

for i in {1..5}; do
    start=$(date +%s%3N)
    result=$(curl -s -o /dev/null -w "%{http_code}" "$TRANSACTION_URL/api/test/slow?delay=100")
    end=$(date +%s%3N)
    cost=$((end - start))
    
    if [ "$result" = "200" ]; then
        echo -e "  请求 $i: HTTP $result, 耗时 ${cost}ms ${GREEN}✓${NC}"
    else
        echo -e "  请求 $i: HTTP $result, 耗时 ${cost}ms ${YELLOW}(被熔断)${NC}"
    fi
    sleep 0.3
done

echo ""
echo -e "${RED}[阶段3] 熔断中 - 快速失败${NC}"
echo "在熔断期间发送请求，会被立即拒绝（耗时<10ms）..."

for i in {1..5}; do
    start=$(date +%s%3N)
    result=$(curl -s -o /dev/null -w "%{http_code}" "$TRANSACTION_URL/api/test/slow?delay=10")
    end=$(date +%s%3N)
    cost=$((end - start))
    
    echo -e "  请求 $i: HTTP $result, 耗时 ${cost}ms ${RED}✗ (熔断中)${NC}"
    sleep 0.5
done

echo ""
echo -e "${YELLOW}[阶段4] 等待熔断恢复...${NC}"
echo "熔断时长为 10 秒，等待恢复..."

for i in {10..1}; do
    echo -ne "  倒计时: $i 秒\r"
    sleep 1
done
echo ""

echo ""
echo -e "${GREEN}[阶段5] 熔断恢复后的请求${NC}"
echo "发送正常请求，应该能成功..."

for i in {1..5}; do
    result=$(curl -s -o /dev/null -w "%{http_code}" "$TRANSACTION_URL/api/test/slow?delay=10")
    if [ "$result" = "200" ]; then
        echo -e "  请求 $i: HTTP $result ${GREEN}✓ (已恢复)${NC}"
    else
        echo -e "  请求 $i: HTTP $result ${YELLOW}(仍在半开状态)${NC}"
    fi
    sleep 0.3
done

echo ""
echo -e "${BLUE}====== 演示完成 ======${NC}"
echo ""
echo "关键观察点："
echo "  ✓ 慢请求触发熔断"
echo "  ✓ 熔断中的请求被快速拒绝（耗时极短）"
echo "  ✓ 10秒后自动恢复"
echo ""
echo "在 Sentinel 控制台可以看到："
echo "  - 实时监控：拒绝QPS的变化曲线"
echo "  - 熔断规则：规则状态的变化"
