#!/bin/bash

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 启动前端开发服务器...${NC}"

# 检查是否在正确目录
if [[ ! -f "../frontend/package.json" ]]; then
    echo -e "${RED}❌ 错误: 请在合约目录下运行此脚本${NC}"
    exit 1
fi

cd ../frontend

# 检查依赖
if [[ ! -d "node_modules" ]]; then
    echo -e "${YELLOW}📦 安装依赖...${NC}"
    pnpm install
fi

echo -e "${GREEN}🎨 启动前端服务器...${NC}"
echo -e "${YELLOW}访问地址: http://localhost:5173${NC}"
echo -e "${YELLOW}按 Ctrl+C 停止服务器${NC}"
echo ""

pnpm dev