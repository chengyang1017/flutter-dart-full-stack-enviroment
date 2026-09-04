#!/bin/bash
# Flutter Playground - 系统诊断脚本

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Flutter Playground - 系统诊断                             ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""

# 1. Docker 状态
echo -e "${BLUE}[1/6] 检查 Docker...${NC}"
if docker ps &> /dev/null; then
    echo -e "${GREEN}✓ Docker 运行正常${NC}"
else
    echo -e "${RED}✗ Docker 未运行${NC}"
    exit 1
fi

# 2. 容器状态
echo -e "${BLUE}[2/6] 检查容器状态...${NC}"
docker-compose ps

# 3. 网络连接
echo ""
echo -e "${BLUE}[3/6] 检查网络连接...${NC}"

APP_STATUS=$(docker-compose exec -T flutter-app curl -s http://localhost/health 2>&1 | head -1 || echo "failed")
if [[ "$APP_STATUS" == *"healthy"* ]]; then
    echo -e "${GREEN}✓ Web 应用健康${NC}"
elif [[ "$APP_STATUS" == "" ]] || [[ "$APP_STATUS" == "failed" ]]; then
    echo -e "${YELLOW}⚠ Web 应用未就绪，可能仍在启动${NC}"
else
    echo -e "${GREEN}✓ Web 应用响应${NC} ($APP_STATUS)"
fi

RUNNER_STATUS=$(docker-compose exec -T flutter-runner curl -s http://localhost:8787/health 2>&1 | head -1 || echo "failed")
if [[ "$RUNNER_STATUS" == *"healthy"* ]]; then
    echo -e "${GREEN}✓ Runner 健康${NC}"
elif [[ "$RUNNER_STATUS" == "" ]] || [[ "$RUNNER_STATUS" == "failed" ]]; then
    echo -e "${YELLOW}⚠ Runner 未就绪，可能仍在启动${NC}"
else
    echo -e "${GREEN}✓ Runner 响应${NC} ($RUNNER_STATUS)"
fi

# 4. 磁盘空间
echo ""
echo -e "${BLUE}[4/6] 检查磁盘空间...${NC}"
DOCKER_DISK=$(docker system df 2>/dev/null | tail -1)
echo -e "Docker: $DOCKER_DISK"

# 5. 资源使用
echo ""
echo -e "${BLUE}[5/6] 检查资源使用...${NC}"
docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}" 2>/dev/null || echo "无法获取实时统计"

# 6. 日志检查
echo ""
echo -e "${BLUE}[6/6] 最近的错误日志...${NC}"
ERROR_COUNT=$(docker-compose logs flutter-app flutter-runner 2>/dev/null | grep -i "error\|failed\|exception" | wc -l || echo "0")
if [ "$ERROR_COUNT" -eq 0 ]; then
    echo -e "${GREEN}✓ 无错误日志${NC}"
else
    echo -e "${YELLOW}⚠ 发现 $ERROR_COUNT 条错误日志${NC}"
    docker-compose logs flutter-app flutter-runner 2>/dev/null | grep -i "error\|failed\|exception" | head -5
fi

echo ""
echo -e "${BLUE}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  诊断完成                                                  ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "更多信息:"
echo "  查看完整日志:    docker-compose logs"
echo "  查看应用日志:    docker-compose logs flutter-app"
echo "  查看 Runner 日志: docker-compose logs flutter-runner"
echo ""
