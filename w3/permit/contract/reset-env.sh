#!/bin/bash

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔄 重置本地测试环境...${NC}"

# 检查当前目录
if [[ ! -f "foundry.toml" ]]; then
    echo -e "${RED}❌ 错误: 请在合约根目录下运行此脚本${NC}"
    exit 1
fi

# 1. 停止现有的 anvil 进程
echo -e "${YELLOW}📋 停止现有的 anvil 进程...${NC}"
pkill -f "anvil" 2>/dev/null || true

# 2. 清理编译缓存
echo -e "${YELLOW}🧹 清理编译缓存...${NC}"
forge clean

# 3. 重新编译合约
echo -e "${YELLOW}🔨 重新编译合约...${NC}"
if ! forge build; then
    echo -e "${RED}❌ 合约编译失败${NC}"
    exit 1
fi

# 4. 启动新的 anvil 实例（后台）
echo -e "${YELLOW}🚀 启动新的 anvil 实例...${NC}"
anvil &
ANVIL_PID=$!

# 等待 anvil 启动
sleep 3

# 检查 anvil 是否成功启动
if ! curl -s http://127.0.0.1:8545 > /dev/null; then
    echo -e "${RED}❌ Anvil 启动失败${NC}"
    kill $ANVIL_PID 2>/dev/null
    exit 1
fi

echo -e "${GREEN}✅ Anvil 已启动 (PID: $ANVIL_PID)${NC}"

# 5. 部署合约并分发代币
echo -e "${YELLOW}📦 部署合约、分发测试代币并设置白名单...${NC}"
if ! forge script script/DeployWithWhitelist.s.sol:DeployWithWhitelistScript --rpc-url http://127.0.0.1:8545 --broadcast > deployment.log 2>&1; then
    echo -e "${RED}❌ 合约部署失败${NC}"
    cat deployment.log
    kill $ANVIL_PID 2>/dev/null
    exit 1
fi

# 6. 提取合约地址并更新 .env
echo -e "${YELLOW}📝 更新合约地址...${NC}"
TOKEN_ADDRESS=$(grep "TTCoin (Token):" deployment.log | awk '{print $3}')
NFT_ADDRESS=$(grep "BaseERC721 (NFT):" deployment.log | awk '{print $3}')
TOKENBANK_ADDRESS=$(grep "TokenBank:" deployment.log | awk '{print $2}')
NFTMARKET_ADDRESS=$(grep "NFTMarket:" deployment.log | awk '{print $2}')

# 更新 .env 文件
cat > .env << EOF
# Anvil 默认的第一个私钥
PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

# Anvil RPC URL
RPC_URL=http://127.0.0.1:8545

# 合约地址：
# TTCoin (Token): $TOKEN_ADDRESS
# BaseERC721 (NFT): $NFT_ADDRESS
# TokenBank: $TOKENBANK_ADDRESS
# NFTMarket: $NFTMARKET_ADDRESS
EOF

# 7. 更新前端配置
echo -e "${YELLOW}🎨 更新前端合约地址...${NC}"
cd ../frontend

# 更新 TokenBank 常量
sed -i.bak "s/export const TOKEN_BANK_ADDRESS = '[^']*'/export const TOKEN_BANK_ADDRESS = '$TOKENBANK_ADDRESS'/" src/features/tokenBank/constants.ts
sed -i.bak "s/export const TOKEN_ADDRESS = '[^']*'/export const TOKEN_ADDRESS = '$TOKEN_ADDRESS'/" src/features/tokenBank/constants.ts

# 更新 NFTMarket 常量
sed -i.bak "s/export const NFT_MARKET_ADDRESS = '[^']*'/export const NFT_MARKET_ADDRESS = '$NFTMARKET_ADDRESS'/" src/features/nftMarket/constants.ts

# 更新 NFT 合约常量
sed -i.bak "s/export const NFT_CONTRACT_ADDRESS = '[^']*'/export const NFT_CONTRACT_ADDRESS = '$NFT_ADDRESS'/" src/features/nft/constants.ts

# 删除备份文件
rm -f src/features/tokenBank/constants.ts.bak
rm -f src/features/nftMarket/constants.ts.bak
rm -f src/features/nft/constants.ts.bak

cd ../contract

# 8. 显示结果
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}🎉 测试环境重置完成！${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "${BLUE}📋 部署信息:${NC}"
echo -e "  TTCoin (Token): ${GREEN}$TOKEN_ADDRESS${NC}"
echo -e "  BaseERC721 (NFT): ${GREEN}$NFT_ADDRESS${NC}"
echo -e "  TokenBank: ${GREEN}$TOKENBANK_ADDRESS${NC}"
echo -e "  NFTMarket: ${GREEN}$NFTMARKET_ADDRESS${NC}"
echo -e ""
echo -e "${BLUE}🔗 网络信息:${NC}"
echo -e "  RPC URL: ${GREEN}http://127.0.0.1:8545${NC}"
echo -e "  Chain ID: ${GREEN}31337${NC}"
echo -e "  Anvil PID: ${GREEN}$ANVIL_PID${NC}"
echo -e ""
echo -e "${BLUE}💰 测试账户已获得:${NC}"
echo -e "  每个账户: ${GREEN}10,000 TTC 代币${NC}"
echo -e "  前3个账户: ${GREEN}各1个测试NFT${NC}"
echo -e ""
echo -e "${YELLOW}📝 下一步:${NC}"
echo -e "  1. 在钱包中添加本地网络 (Chain ID: 31337)"
echo -e "  2. 导入测试私钥到钱包"
echo -e "  3. 启动前端: ${GREEN}cd ../frontend && pnpm dev${NC}"
echo -e ""
echo -e "${YELLOW}🛑 停止测试环境:${NC}"
echo -e "  ${GREEN}kill $ANVIL_PID${NC}"

# 保存 PID 到文件，方便后续停止
echo $ANVIL_PID > anvil.pid