#!/bin/bash
# Flutter Playground - 快速启动脚本

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Flutter Playground - Docker Compose 快速启动             ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════════╝${NC}"

# 检查 Docker
if ! command -v docker &> /dev/null; then
    echo -e "${RED}✗ Docker 未安装${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Docker${NC} $(docker --version)"

# 检查 Docker Compose
if ! command -v docker-compose &> /dev/null; then
    echo -e "${RED}✗ Docker Compose 未安装${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Docker Compose${NC} $(docker-compose --version)"

# 环境配置
if [ ! -f .env ]; then
    echo -e "${YELLOW}⚠ .env 文件不存在，使用默认配置${NC}"
    cp .env.example .env
fi

echo ""
echo -e "${BLUE}启动服务...${NC}"

# 启动服务
docker-compose up -d

echo ""
echo -e "${GREEN}✓ 服务启动成功！${NC}"
echo ""

# 等待服务就绪
echo -e "${BLUE}等待服务就绪...${NC}"
sleep 5

# 检查服务健康状态
echo -e "${BLUE}检查服务状态...${NC}"

APP_HEALTH=$(docker-compose exec -T flutter-app wget --quiet --tries=1 --spider http://localhost/health 2>&1 || echo "failed")
RUNNER_HEALTH=$(docker-compose exec -T flutter-runner wget --quiet --tries=1 --spider http://localhost:8787/health 2>&1 || echo "failed")

if [[ "$APP_HEALTH" == *"failed"* ]]; then
    echo -e "${RED}✗ Web 应用未就绪${NC}"
else
    echo -e "${GREEN}✓ Web 应用${NC}"
fi

if [[ "$RUNNER_HEALTH" == *"failed"* ]]; then
    echo -e "${RED}✗ Runner 未就绪${NC}"
else
    echo -e "${GREEN}✓ Runner${NC}"
fi

echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                    🚀 启动完成！                           ║${NC}"
echo -e "${GREEN}╠═══════════════════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║  Web 应用: ${BLUE}http://localhost:8080${GREEN}                       ║${NC}"
echo -e "${GREEN}║  Runner:   ${BLUE}http://localhost:8787${GREEN}                       ║${NC}"
echo -e "${GREEN}║                                                           ║${NC}"
echo -e "${GREEN}║  查看日志:     ${YELLOW}docker-compose logs -f${GREEN}                   ║${NC}"
echo -e "${GREEN}║  停止服务:     ${YELLOW}docker-compose down${GREEN}                      ║${NC}"
echo -e "${GREEN}║  查看状态:     ${YELLOW}docker-compose ps${GREEN}                        ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""

# 打开浏览器 (macOS)
if [[ "$OSTYPE" == "darwin"* ]]; then
    sleep 2
    open "http://localhost:8080" || true
fi

# 打开浏览器 (Linux)
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    sleep 2
    xdg-open "http://localhost:8080" 2>/dev/null || true
fi
