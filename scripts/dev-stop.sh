#!/bin/bash
# ============================================================
# 快速停止所有微服务
# 用法: ./dev-stop.sh
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
MICROSERVICES_DIR="$PROJECT_ROOT/microservices"

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

echo -e "${RED}===== 停止微服务 =====${NC}"

# 停止微服务进程
for pid_file in "$MICROSERVICES_DIR/logs"/*.pid; do
    if [ -f "$pid_file" ]; then
        pid=$(cat "$pid_file")
        name=$(basename "$pid_file" .pid)
        if kill -0 "$pid" 2>/dev/null; then
            echo "停止 $name (PID: $pid)..."
            kill "$pid" 2>/dev/null
        fi
        rm -f "$pid_file"
    fi
done

# 备选：按端口杀进程
ports=(9000 8081 8082 8083 8084)
for port in "${ports[@]}"; do
    pid=$(lsof -ti:$port 2>/dev/null)
    if [ -n "$pid" ]; then
        echo "停止端口 $port 上的进程 (PID: $pid)..."
        kill $pid 2>/dev/null
    fi
done

echo ""
echo -e "${GREEN}微服务已停止${NC}"
echo ""
echo "如需停止基础设施，运行:"
echo "  docker compose -f docker-compose.microservices.yml down"
