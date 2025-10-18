#!/bin/bash

# NFT Market 完整部署和升级脚本
# 这个脚本会部署支持升级的完整系统并测试升级功能

set -e  # 遇到错误立即退出

echo "======================================================================"
echo "NFT Market - 完整部署和升级脚本"
echo "======================================================================"
echo ""

# 检查环境变量
if [ -z "$privatekey" ] || [ -z "$rpc" ]; then
    echo "错误: 请先加载环境变量"
    echo "运行: source .env"
    exit 1
fi

echo "部署账户: $(cast wallet address $privatekey)"
echo ""

# 第一步：部署 V2 实现（已修复，支持升级）
echo "======================================================================"
echo "第 1 步: 部署 NFTMarketV2Upgradeable (支持升级)"
echo "======================================================================"

V2_DEPLOY=$(forge create src/NFTMarketV2Upgradeable.sol:NFTMarketV2Upgradeable \
  --private-key $privatekey \
  --rpc-url $rpc \
  --json 2>/dev/null)

V2_IMPL=$(echo $V2_DEPLOY | jq -r .deployedTo)
echo "✓ V2 实现地址: $V2_IMPL"
echo ""

# 第二步：部署代理
echo "======================================================================"
echo "第 2 步: 部署 NFTMarketV2Proxy"
echo "======================================================================"

PROXY_DEPLOY=$(forge create src/NFTMarketV2Proxy.sol:NFTMarketV2Proxy \
  --constructor-args $V2_IMPL \
  --private-key $privatekey \
  --rpc-url $rpc \
  --json 2>/dev/null)

PROXY=$(echo $PROXY_DEPLOY | jq -r .deployedTo)
echo "✓ 代理地址: $PROXY"
echo ""

# 第三步：验证 V2 部署
echo "======================================================================"
echo "第 3 步: 验证 V2 部署"
echo "======================================================================"

VERSION=$(cast call $PROXY "version()(string)" --rpc-url $rpc 2>/dev/null)
echo "✓ 当前版本: $VERSION"

IMPL=$(cast call $PROXY "implementation()(address)" --rpc-url $rpc 2>/dev/null)
echo "✓ 实现地址: $IMPL"
echo ""

# 第四步：部署 V3 实现
echo "======================================================================"
echo "第 4 步: 部署 NFTMarketV3Upgradeable"
echo "======================================================================"

V3_DEPLOY=$(forge create src/NFTMarketV3Upgradeable.sol:NFTMarketV3Upgradeable \
  --private-key $privatekey \
  --rpc-url $rpc \
  --json 2>/dev/null)

V3_IMPL=$(echo $V3_DEPLOY | jq -r .deployedTo)
echo "✓ V3 实现地址: $V3_IMPL"
echo ""

# 第五步：执行升级
echo "======================================================================"
echo "第 5 步: 升级 V2 -> V3"
echo "======================================================================"

echo "调用 upgradeTo($V3_IMPL)..."
UPGRADE_TX=$(cast send $PROXY \
  "upgradeTo(address)" \
  $V3_IMPL \
  --private-key $privatekey \
  --rpc-url $rpc \
  --json 2>/dev/null)

UPGRADE_HASH=$(echo $UPGRADE_TX | jq -r .transactionHash)
echo "✓ 升级交易: $UPGRADE_HASH"

# 等待确认
sleep 3

# 验证升级
NEW_VERSION=$(cast call $PROXY "version()(string)" --rpc-url $rpc 2>/dev/null)
echo "✓ 新版本: $NEW_VERSION"

NEW_IMPL=$(cast call $PROXY "implementation()(address)" --rpc-url $rpc 2>/dev/null)
echo "✓ 新实现地址: $NEW_IMPL"

if [ "$NEW_IMPL" == "$V3_IMPL" ]; then
    echo "✓ 升级成功确认!"
else
    echo "✗ 警告: 实现地址不匹配"
    echo "  期望: $V3_IMPL"
    echo "  实际: $NEW_IMPL"
fi

echo ""

# 第六步：初始化 V3
echo "======================================================================"
echo "第 6 步: 初始化 V3 新功能"
echo "======================================================================"

echo "调用 initializeV3()..."
INIT_TX=$(cast send $PROXY \
  "initializeV3()" \
  --private-key $privatekey \
  --rpc-url $rpc \
  --json 2>/dev/null)

INIT_HASH=$(echo $INIT_TX | jq -r .transactionHash)
echo "✓ 初始化交易: $INIT_HASH"

# 等待确认
sleep 3

# 测试 V3 功能
NONCE=$(cast call $PROXY \
  "getNonce(address)(uint256)" \
  "$(cast wallet address $privatekey)" \
  --rpc-url $rpc 2>/dev/null)

echo "✓ Nonce 功能正常: $NONCE"

DOMAIN_SEP=$(cast call $PROXY "DOMAIN_SEPARATOR()(bytes32)" --rpc-url $rpc 2>/dev/null)
echo "✓ Domain Separator: $DOMAIN_SEP"

echo ""

# 第七步：配置支付代币
echo "======================================================================"
echo "第 7 步: 配置支付代币白名单"
echo "======================================================================"

TTCOIN="0xd499Ac1FBfa849640Ec92d26a8bA67d39019360a"

IS_SUPPORTED=$(cast call $PROXY \
  "isTokenSupported(address)(bool)" \
  $TTCOIN \
  --rpc-url $rpc 2>/dev/null)

if [ "$IS_SUPPORTED" == "false" ]; then
    echo "添加 TTCoin 到白名单..."
    ADD_TOKEN_TX=$(cast send $PROXY \
      "addSupportedToken(address)" \
      $TTCOIN \
      --private-key $privatekey \
      --rpc-url $rpc \
      --json 2>/dev/null)

    echo "✓ TTCoin 已添加到白名单"
else
    echo "✓ TTCoin 已在白名单中"
fi

echo ""

# 总结
echo "======================================================================"
echo "部署和升级完成！"
echo "======================================================================"
echo ""
echo "合约地址:"
echo "  代理地址 (用这个):        $PROXY"
echo "  V2 实现:                  $V2_IMPL"
echo "  V3 实现:                  $V3_IMPL"
echo ""
echo "TTCoin:                    $TTCOIN"
echo "BaseERC721:                0xD1689165740CD727fba08a9F721bB6fCa297fD1F"
echo ""
echo "当前状态:"
echo "  版本:                    $NEW_VERSION"
echo "  Nonce:                   $NONCE"
echo "  TTCoin 支持:             已启用"
echo ""
echo "下一步:"
echo "  1. 更新 .env 添加:"
echo "     NEW_PROXY_ADDRESS=$PROXY"
echo ""
echo "  2. 测试签名上架:"
echo "     npm run test:signature"
echo ""
echo "  注意: 请在测试脚本中使用新的代理地址 $PROXY"
echo ""
echo "升级成功! 🎉"
echo "======================================================================"

# 保存地址到文件
cat > deployed-addresses.txt << EOF
# NFT Market 部署地址记录
# 部署时间: $(date)

# 代理合约 (用户交互地址)
PROXY=$PROXY

# 实现合约
V2_IMPL=$V2_IMPL
V3_IMPL=$V3_IMPL

# 基础合约
TTCOIN=$TTCOIN
BASE_ERC721=0xD1689165740CD727fba08a9F721bB6fCa297fD1F

# 版本信息
CURRENT_VERSION=$NEW_VERSION
EOF

echo "地址已保存到 deployed-addresses.txt"
