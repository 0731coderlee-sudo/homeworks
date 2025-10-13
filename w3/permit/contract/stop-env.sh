#!/bin/bash

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}🛑 停止测试环境...${NC}"

# 停止 anvil 进程
if [[ -f "anvil.pid" ]]; then
    ANVIL_PID=$(cat anvil.pid)
    if kill $ANVIL_PID 2>/dev/null; then
        echo -e "${GREEN}✅ 已停止 Anvil (PID: $ANVIL_PID)${NC}"
    else
        echo -e "${YELLOW}⚠️  Anvil 进程可能已经停止${NC}"
    fi
    rm -f anvil.pid
else
    echo -e "${YELLOW}⚠️  没有找到 anvil.pid 文件，尝试停止所有 anvil 进程...${NC}"
    pkill -f "anvil" && echo -e "${GREEN}✅ 已停止所有 anvil 进程${NC}" || echo -e "${YELLOW}⚠️  没有找到运行中的 anvil 进程${NC}"
fi

echo -e "${GREEN}🎉 测试环境已停止${NC}"