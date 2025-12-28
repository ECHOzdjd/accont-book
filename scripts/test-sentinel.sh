#!/bin/bash
# ============================================================
# Sentinel 熔断规则测试脚本
# 用法: ./test-sentinel.sh [场景]
# 场景: normal | slow | error | concurrent
# ============================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 颜色
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# API端点
GATEWAY_URL="http://localhost:9000"
TRANSACTION_URL="http://localhost:8083"

echo -e "${BLUE}===== Sentinel 熔断测试工具 =====${NC}"
echo ""

# 场景1: 正常请求测试
test_normal() {
    echo -e "${GREEN}[场景1] 正常请求测试${NC}"
    echo "发送10个正常请求..."
    
    for i in {1..10}; do
        response=$(curl -s -w "\n%{http_code}" "$TRANSACTION_URL/api/transactions/user/1")
        http_code=$(echo "$response" | tail -n1)
        
        if [ "$http_code" = "200" ]; then
            echo -e "${GREEN}✓${NC} 请求 $i: 成功 (HTTP $http_code)"
        else
            echo -e "${RED}✗${NC} 请求 $i: 失败 (HTTP $http_code)"
        fi
        sleep 0.3
    done
    
    echo ""
    echo -e "${YELLOW}提示: 前往 Sentinel 控制台查看 QPS 和调用数据${NC}"
}

# 场景2: 慢调用测试（需要先在 Sentinel 配置慢调用规则）
test_slow() {
    echo -e "${GREEN}[场景2] 慢调用压力测试${NC}"
    echo "连续发送50个快速请求，模拟高并发..."
    echo -e "${YELLOW}请确保在 Sentinel 已配置：${NC}"
    echo "  - 资源: /api/transactions/user/{userId}"
    echo "  - 策略: 慢调用比例"
    echo "  - 最大RT: 100ms"
    echo "  - 比例阈值: 0.5"
    echo ""
    
    success=0
    blocked=0
    error=0
    
    for i in {1..50}; do
        response=$(curl -s -w "\n%{http_code}" "$TRANSACTION_URL/api/transactions/user/1" 2>/dev/null || echo -e "\n000")
        http_code=$(echo "$response" | tail -n1)
        
        if [ "$http_code" = "200" ]; then
            ((success++))
            echo -ne "${GREEN}✓${NC}"
        elif [ "$http_code" = "429" ] || echo "$response" | grep -q "Blocked by Sentinel"; then
            ((blocked++))
            echo -ne "${YELLOW}B${NC}"
        else
            ((error++))
            echo -ne "${RED}✗${NC}"
        fi
        
        # 每10个请求换行
        if [ $((i % 10)) -eq 0 ]; then
            echo " ($i/50)"
        fi
        
        sleep 0.05
    done
    
    echo ""
    echo ""
    echo "测试结果:"
    echo -e "  ${GREEN}成功: $success${NC}"
    echo -e "  ${YELLOW}被熔断: $blocked${NC}"
    echo -e "  ${RED}错误: $error${NC}"
    
    if [ $blocked -gt 0 ]; then
        echo ""
        echo -e "${GREEN}✓ 熔断规则已生效！${NC}"
    else
        echo ""
        echo -e "${YELLOW}⚠ 未触发熔断，请检查：${NC}"
        echo "  1. Sentinel 规则是否正确配置"
        echo "  2. 最大RT阈值是否过高"
        echo "  3. 最小请求数是否满足"
    fi
}

# 场景3: 异常请求测试
test_error() {
    echo -e "${GREEN}[场景3] 异常请求测试${NC}"
    echo "发送错误请求触发异常..."
    echo -e "${YELLOW}请确保在 Sentinel 已配置：${NC}"
    echo "  - 资源: /api/transactions (POST)"
    echo "  - 策略: 异常比例"
    echo "  - 比例阈值: 0.5"
    echo ""
    
    success=0
    error=0
    blocked=0
    
    for i in {1..20}; do
        # 发送无效数据导致异常
        response=$(curl -s -w "\n%{http_code}" -X POST \
            -H "Content-Type: application/json" \
            -d '{"assetId":999999,"type":1,"category":"测试","amount":-100}' \
            "$TRANSACTION_URL/api/transactions" 2>/dev/null || echo -e "\n000")
        
        http_code=$(echo "$response" | tail -n1)
        
        if [ "$http_code" = "200" ]; then
            ((success++))
            echo -ne "${GREEN}✓${NC}"
        elif [ "$http_code" = "429" ] || echo "$response" | grep -q "Blocked"; then
            ((blocked++))
            echo -ne "${YELLOW}B${NC}"
        else
            ((error++))
            echo -ne "${RED}E${NC}"
        fi
        
        if [ $((i % 10)) -eq 0 ]; then
            echo " ($i/20)"
        fi
        
        sleep 0.2
    done
    
    echo ""
    echo ""
    echo "测试结果:"
    echo -e "  ${GREEN}成功: $success${NC}"
    echo -e "  ${RED}异常: $error${NC}"
    echo -e "  ${YELLOW}被熔断: $blocked${NC}"
}

# 场景4: 并发压力测试
test_concurrent() {
    echo -e "${GREEN}[场景4] 并发压力测试${NC}"
    echo "启动10个并发客户端，每个发送10个请求..."
    echo ""
    
    temp_dir="/tmp/sentinel-test-$$"
    mkdir -p "$temp_dir"
    
    # 并发执行
    for client in {1..10}; do
        (
            for req in {1..10}; do
                response=$(curl -s -w "\n%{http_code}" "$TRANSACTION_URL/api/transactions/user/1" 2>/dev/null || echo -e "\n000")
                http_code=$(echo "$response" | tail -n1)
                echo "$http_code" >> "$temp_dir/client_${client}.log"
                sleep 0.1
            done
        ) &
    done
    
    # 等待所有并发完成
    wait
    
    # 统计结果
    total_requests=0
    success_count=0
    blocked_count=0
    error_count=0
    
    for log in "$temp_dir"/client_*.log; do
        if [ -f "$log" ]; then
            while read -r code; do
                ((total_requests++))
                if [ "$code" = "200" ]; then
                    ((success_count++))
                elif [ "$code" = "429" ]; then
                    ((blocked_count++))
                else
                    ((error_count++))
                fi
            done < "$log"
        fi
    done
    
    # 清理
    rm -rf "$temp_dir"
    
    echo "并发测试完成！"
    echo ""
    echo "测试结果:"
    echo -e "  总请求数: $total_requests"
    echo -e "  ${GREEN}成功: $success_count${NC}"
    echo -e "  ${YELLOW}被限流/熔断: $blocked_count${NC}"
    echo -e "  ${RED}错误: $error_count${NC}"
    
    if [ $blocked_count -gt 0 ]; then
        echo ""
        echo -e "${GREEN}✓ 流控/熔断规则已生效！${NC}"
    fi
}

# 显示菜单
show_menu() {
    echo "请选择测试场景:"
    echo "  1) normal     - 正常请求测试"
    echo "  2) slow       - 慢调用熔断测试"
    echo "  3) error      - 异常熔断测试"
    echo "  4) concurrent - 并发压力测试"
    echo "  5) all        - 运行所有测试"
    echo ""
}

# 主逻辑
case "${1:-menu}" in
    normal)
        test_normal
        ;;
    slow)
        test_slow
        ;;
    error)
        test_error
        ;;
    concurrent)
        test_concurrent
        ;;
    all)
        test_normal
        echo ""
        test_slow
        echo ""
        test_error
        echo ""
        test_concurrent
        ;;
    menu|*)
        show_menu
        read -p "请输入选项 (1-5): " choice
        case $choice in
            1) test_normal ;;
            2) test_slow ;;
            3) test_error ;;
            4) test_concurrent ;;
            5)
                test_normal
                echo ""
                test_slow
                echo ""
                test_error
                echo ""
                test_concurrent
                ;;
            *) echo -e "${RED}无效选项${NC}" ;;
        esac
        ;;
esac

echo ""
echo -e "${BLUE}===== 测试完成 =====${NC}"
echo "查看实时监控: http://localhost:8858"
