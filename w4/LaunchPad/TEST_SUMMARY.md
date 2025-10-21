# MemeFactory 测试总结

## 测试结果
✅ **14/14 测试全部通过**

## 测试覆盖

### 1. 基础功能测试
- ✅ `testDeployFactory` - 测试工厂合约部署
- ✅ `testDeployMeme` - 测试 Meme 代币创建
- ✅ `testCannotInitializeTwice` - 测试防止重复初始化

### 2. Mint 功能测试
- ✅ `testMintMeme` - 测试基本 mint 功能和费用分配
- ✅ `testMintMemeAddsLiquidity` - 测试自动添加 Uniswap 流动性
- ✅ `testMultipleMints` - 测试多次 mint
- ✅ `testFeeDistribution` - 测试费用分配（95% 创建者 + 5% 流动性）

### 3. Uniswap 交互测试
- ✅ `testBuyMemeFromUniswap` - 测试从 Uniswap 购买
- ✅ `testGetUniswapPrice` - 测试价格查询
- ✅ `testIsUniswapBetter` - 测试价格比较功能

### 4. 边界情况测试
- ✅ `testInsufficientPayment` - 测试支付不足的保护
- ✅ `testRefundExcessPayment` - 测试多余支付的退款
- ✅ `testExceedTotalSupply` - 测试超过总供应量的保护

### 5. 多代币测试
- ✅ `testMultipleTokens` - 测试多个 Meme 代币独立运作

## 测试场景

### 场景 1：完整的 Meme 币生命周期
```solidity
1. Alice 创建 PEPE 代币
   - totalSupply: 1,000,000 PEPE
   - perMint: 100 PEPE
   - price: 0.01 ETH/token

2. Bob 购买 PEPE（mintMeme）
   - 支付: 1 ETH
   - 获得: 100 PEPE
   - Alice 收益: 0.95 ETH
   - 流动性池: 0.05 ETH + 5 PEPE

3. Carol 从 Uniswap 购买（buyMeme）
   - 支付: 0.5 ETH
   - 获得: ~4.5 PEPE（根据 AMM 价格）
```

### 场景 2：价格套利
```solidity
1. Uniswap 价格 < Mint 价格
   → 用户调用 buyMeme() 从 Uniswap 购买（更便宜）

2. Uniswap 价格 > Mint 价格
   → 用户调用 mintMeme() 直接铸造（更便宜）

3. 价格自动平衡
   → 套利者确保价格围绕 mint price 波动
```

## Mock 合约

为了在本地测试 Uniswap 交互，创建了以下 Mock 合约：

1. **MockWETH** - 模拟 Wrapped ETH
2. **MockUniswapV2Factory** - 模拟 Uniswap V2 工厂
3. **MockUniswapV2Pair** - 模拟 Uniswap V2 交易对
4. **MockUniswapV2Router** - 模拟 Uniswap V2 路由器

## 运行测试

```bash
# 运行所有测试
forge test

# 运行特定测试（详细输出）
forge test --match-test testMintMeme -vvvv

# 运行测试并查看 gas 使用
forge test --gas-report

# 运行测试并查看覆盖率
forge coverage
```

## Gas 消耗估算

| 操作 | Gas 消耗 |
|------|----------|
| deployMeme | ~165k gas |
| mintMeme（首次，创建池子）| ~1.3M gas |
| mintMeme（后续）| ~1.3M gas |
| buyMeme | ~1.4M gas |
| getUniswapPrice (view) | 0 gas |

## 关键发现

### 1. 流动性自动添加
每次 `mintMeme()` 调用都会自动将 5% 的 ETH 和对应的 Token 添加到 Uniswap 流动性池，确保代币始终可交易。

### 2. 双轨购买机制
- `mintMeme()`: 固定价格铸造，适合价格稳定期
- `buyMeme()`: 市场价格购买，适合套利

### 3. 费用分配透明
- 95% 给创建者（激励创作）
- 5% 自动添加流动性（确保可交易性）
- 项目方获得 LP Token（长期收益）

### 4. 安全保护
- ✅ 防止重复初始化
- ✅ 支付不足保护
- ✅ 自动退款多余 ETH
- ✅ 总供应量限制

## 本地模拟

所有测试在本地 Foundry 环境运行，使用 Mock 合约模拟 Uniswap V2：
- ✅ 完整的 AMM 价格计算
- ✅ 流动性添加/移除
- ✅ Token 兑换
- ✅ 储备金管理

无需部署到测试网即可完整测试所有功能！
