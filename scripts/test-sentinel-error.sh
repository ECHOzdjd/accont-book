#!/bin/bash
# ============================================================
# Sentinel 异常熔断测试脚本
# ============================================================

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

TRANSACTION_URL="http://localhost:8083"

echo -e "${BLUE}===== Sentinel 异常熔断测试 =====${NC}"
echo ""

# 预热
echo -e "${GREEN}[预热] 让 Sentinel 识别资源${NC}"
for i in {1..3}; do
    curl -s "$TRANSACTION_URL/api/test/error?throwError=false" > /dev/null
    echo "  ✓ 预热请求 $i"
done

echo ""
echo -e "${YELLOW}请在 Sentinel 控制台配置异常熔断规则：${NC}"
echo "  1. '簇点链路' 找到 '/api/test/error' 资源"
echo "  2. 点击 '熔断' 按钮"
echo "  3. 配置："
echo "     - 熔断策略: 异常比例"
echo "     - 比例阈值: 0.5"
echo "     - 熔断时长: 10 秒"
echo "     - 最小请求数: 3"
echo "     - 统计时长: 1000 毫秒"
echo "  4. 保存"
echo ""
read -p "配置完成后按回车继续..."

echo ""
echo -e "${GREEN}[测试] 发送请求（70%会抛异常）${NC}"
echo ""

success=0
exception=0
blocked=0

for i in {1..20}; do
    # 70%概率抛异常
    if [ $((i % 10)) -lt 7 ]; then
        throw_error="true"
    else
        throw_error="false"
    fi
    
    result=$(curl -s -o /dev/null -w "%{http_code}" "$TRANSACTION_URL/api/test/error?throwError=$throw_error" 2>/dev/null)
    
    if [ "$result" = "200" ]; then
        echo -ne "${GREEN}✓${NC}"
        ((success++))
    elif [ "$result" = "500" ]; then
        echo -ne "${RED}E${NC}"
        ((exception++))
    elif [ "$result" = "429" ]; then
        echo -ne "${YELLOW}B${NC}"
        ((blocked++))
    fi
    
    if [ $((i % 10)) -eq 0 ]; then
        echo " ($i/20)"
    fi
    
    sleep 0.2
done

echo ""
echo ""
echo -e "${BLUE}====== 测试结果 ======${NC}"
echo -e "  ${GREEN}成功: $success${NC}"
echo -e "  ${RED}异常: $exception${NC}"
echo -e "  ${YELLOW}被熔断: $blocked${NC}"

if [ $blocked -gt 0 ]; then
    echo ""
    echo -e "${GREEN}✅ 异常熔断规则成功触发！${NC}"
else
    echo ""
    echo -e "${YELLOW}⚠ 异常熔断未触发，请检查规则配置${NC}"
fi
