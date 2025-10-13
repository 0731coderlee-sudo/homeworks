#!/bin/bash

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 一键启动完整测试环境${NC}"
echo -e "${BLUE}================================${NC}"

# 1. 重置环境
echo -e "${YELLOW}步骤 1/2: 重置测试环境...${NC}"
if ! ./reset-env.sh; then
    echo -e "${RED}❌ 环境重置失败${NC}"
    exit 1
fi

echo -e "${GREEN}✅ 环境重置完成${NC}"
echo ""

# 2. 等待用户确认
echo -e "${YELLOW}步骤 2/2: 准备启动前端...${NC}"
echo -e "${BLUE}📝 请先完成以下步骤:${NC}"
echo -e "  1. 在钱包中添加本地网络:"
echo -e "     - 网络名称: ${GREEN}Anvil Local${NC}"
echo -e "     - RPC URL: ${GREEN}http://127.0.0.1:8545${NC}"
echo -e "     - Chain ID: ${GREEN}31337${NC}"
echo -e "     - 货币符号: ${GREEN}ETH${NC}"
echo -e ""
echo -e "  2. 导入测试账户 (任选一个):"
echo -e "     - Account #1: ${GREEN}0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d${NC}"
echo -e "     - Account #2: ${GREEN}0x5de4111afa1a4b94908f83103c3ad2d63a3e2b3f84e6e79fe1b7c5cbd1e4c3a${NC}"
echo -e "     - Account #3: ${GREEN}0x7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6${NC}"
echo -e ""

read -p "完成钱包设置后，按 Enter 键启动前端... " -r

echo -e "${GREEN}🎨 启动前端...${NC}"
./start-frontend.sh