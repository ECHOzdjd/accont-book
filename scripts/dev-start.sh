#!/bin/bash
# ============================================================
# 开发环境快速启动脚本 (修复版)
# 用法: ./dev-start.sh
# ============================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 颜色
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}===== 微服务开发环境启动 =====${NC}"
echo ""

# 微服务目录
MICROSERVICES_DIR="$PROJECT_ROOT/microservices"

# 创建日志目录
mkdir -p "$MICROSERVICES_DIR/logs"

# 1. 启动基础设施
echo -e "${GREEN}[1/4] 启动基础设施...${NC}"
cd "$PROJECT_ROOT"
docker compose -f docker-compose.microservices.yml up -d mysql nacos rabbitmq

echo -e "${YELLOW}等待基础设施就绪...${NC}"
for i in {1..30}; do
    if curl -s http://localhost:8848/nacos/ > /dev/null 2>&1 && \
       docker exec accont-mysql mysqladmin ping -h localhost -uroot -proot123 2>/dev/null | grep -q alive; then
        echo -e "${GREEN}基础设施已就绪${NC}"
        break
    fi
    sleep 2
    echo -n "."
done
echo ""

# 2. 检查JAR文件
echo -e "${GREEN}[2/4] 检查JAR文件...${NC}"
NEED_BUILD=false
for svc in gateway-service user-service asset-service transaction-service statistics-service; do
    jar="$MICROSERVICES_DIR/$svc/target/$svc-1.0.0-SNAPSHOT.jar"
    if [ ! -f "$jar" ] || [ $(stat -c%s "$jar") -lt 1000000 ]; then
        NEED_BUILD=true
        break
    fi
done

if [ "$NEED_BUILD" = true ]; then
    echo -e "${YELLOW}需要构建...${NC}"
    cd "$MICROSERVICES_DIR"
    mvn clean package -DskipTests
fi

# 3. 启动微服务
echo ""
echo -e "${GREEN}[3/4] 启动微服务...${NC}"
cd "$MICROSERVICES_DIR"

echo "  启动 gateway-service (9000)..."
java -jar gateway-service/target/gateway-service-1.0.0-SNAPSHOT.jar > logs/gateway.log 2>&1 &
sleep 8

echo "  启动 user-service (8081)..."
java -jar user-service/target/user-service-1.0.0-SNAPSHOT.jar > logs/user.log 2>&1 &

echo "  启动 asset-service (8082)..."
java -jar asset-service/target/asset-service-1.0.0-SNAPSHOT.jar > logs/asset.log 2>&1 &
sleep 5

echo "  启动 transaction-service (8083)..."
java -jar transaction-service/target/transaction-service-1.0.0-SNAPSHOT.jar > logs/transaction.log 2>&1 &
sleep 10

echo "  启动 statistics-service (8084)..."
java -jar statistics-service/target/statistics-service-1.0.0-SNAPSHOT.jar > logs/statistics.log 2>&1 &

# 4. 等待服务就绪
echo ""
echo -e "${GREEN}[4/4] 等待服务就绪...${NC}"
sleep 15

echo ""
echo "===== 服务状态 ====="
for port in 9000 8081 8082 8083 8084; do
    if curl -s "http://localhost:$port/actuator/health" | grep -q "UP"; then
        echo -e "  端口 $port: ${GREEN}✓ 运行中${NC}"
    else
        echo -e "  端口 $port: ${RED}✗ 未就绪${NC}"
    fi
done

echo ""
echo "===== 服务端点 ====="
echo "  网关:     http://localhost:9000"
echo "  用户:     http://localhost:8081"
echo "  资产:     http://localhost:8082"
echo "  交易:     http://localhost:8083"
echo "  统计:     http://localhost:8084"
echo ""
echo "  Nacos:    http://localhost:8848/nacos/"
echo "  RabbitMQ: http://localhost:15672 (guest/guest)"
echo ""
echo -e "${GREEN}启动完成！${NC}"
echo "停止服务: ./scripts/dev-stop.sh"
echo "运行测试: ./scripts/test-api.sh"
