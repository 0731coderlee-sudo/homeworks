# MemeFactory - Meme 币发射平台

一个基于 EIP-1167 最小代理模式的 Meme 代币发射平台，集成了 Uniswap V2 自动流动性添加功能。

## 功能特性

### 🚀 核心功能
- **极低 Gas 部署**: 使用 EIP-1167 最小代理，每个代币只需 ~165k gas
- **自动流动性**: 每笔购买自动添加 5% ETH + Token 到 Uniswap
- **双轨购买**: 支持固定价格铸造 + Uniswap 市场购买
- **费用分配**: 95% 给创建者，5% 自动做市

### 📊 智能价格发现
- `mintMeme()`: 按固定价格铸造
- `buyMeme()`: 从 Uniswap 按市场价购买
- `isUniswapBetter()`: 自动比较最优价格

## 架构设计

```
MemeFactory (工厂合约)
    │
    ├─ Implementation (MemeToken 逻辑合约)
    │
    └─ deployMeme() ──> 创建最小代理 (45 字节)
                            │
                            ├─ Proxy 1 (PEPE token)
                            ├─ Proxy 2 (DOGE token)
                            └─ Proxy 3 (SHIB token)
```

## 快速开始

### 安装依赖
```bash
# 已使用 Foundry，无需额外安装
forge --version
```

### 运行测试
```bash
# 运行所有测试
forge test

# 详细输出
forge test -vv

# 查看特定测试
forge test --match-test testMintMeme -vvvv

# Gas 报告
forge test --gas-report
```

### 编译合约
```bash
forge build
```

## 部署

### 1. 部署到本地网络
```bash
# 启动本地节点
anvil

# 部署合约
forge script script/Deploy.s.sol --rpc-url http://localhost:8545 --broadcast
```

### 2. 部署到 Sepolia
```bash
forge create src/MemeFactory.sol:MemeFactory \
    --rpc-url $SEPOLIA_RPC_URL \
    --private-key $PRIVATE_KEY \
    --constructor-args 0xeE567Fe1712Faf6149d80dA1E6934E354124CfE3
```
> Sepolia Uniswap V2Router: `0xeE567Fe1712Faf6149d80dA1E6934E354124CfE3`

## 使用示例

### 创建 Meme 币
```solidity
// 参数：symbol, totalSupply, perMint, price
address pepeToken = factory.deployMeme(
    "PEPE",           // 代币符号
    1000000 ether,    // 总供应量 1,000,000
    100 ether,        // 每次铸造数量 100
    0.01 ether       // 价格 0.01 ETH/token
);
```

### 购买 Meme 币

#### 方式 1：固定价格铸造
```solidity
// Bob 支付 1 ETH 购买 100 PEPE
factory.mintMeme{value: 1 ether}(pepeToken);

// 资金流向：
// - 0.95 ETH → 创建者
// - 0.05 ETH + 5 PEPE → Uniswap 流动性
// - 100 PEPE → Bob
```

#### 方式 2：Uniswap 市场价
```solidity
// Carol 从 Uniswap 购买（按市场价）
factory.buyMeme{value: 0.5 ether}(pepeToken);
```

#### 智能选择最优价格
```solidity
// 检查哪种方式更优
bool uniswapBetter = factory.isUniswapBetter(pepeToken, 1 ether);

if (uniswapBetter) {
    factory.buyMeme{value: 1 ether}(pepeToken);
} else {
    factory.mintMeme{value: 1 ether}(pepeToken);
}
```

## 测试覆盖

✅ **14/14 测试全部通过**

详细测试报告见 [TEST_SUMMARY.md](./TEST_SUMMARY.md)

### 测试类别
- 基础功能（部署、初始化）
- Mint 功能（铸造、费用分配）
- Uniswap 交互（购买、价格查询）
- 边界情况（支付保护、供应限制）
- 多代币测试

## 合约地址

### Sepolia Testnet
- Uniswap V2 Router: `0xeE567Fe1712Faf6149d80dA1E6934E354124CfE3`
- MemeFactory: *待部署*

## 技术栈

- **Solidity 0.8+**: 智能合约语言
- **Foundry**: 开发框架和测试工具
- **EIP-1167**: 最小代理模式
- **Uniswap V2**: DEX 集成

## 安全考虑

- ✅ 防止重复初始化
- ✅ 支付验证和退款
- ✅ 总供应量限制
- ⚠️ 当前无滑点保护（建议生产环境添加）
- ⚠️ Mint 权限需要进一步限制

## Gas 优化

| 操作 | Gas 消耗 |
|------|---------|
| 部署完整 ERC20 | ~2M gas |
| 部署最小代理 | ~165k gas |
| 节省 | **92%** ⬇️ |

## 许可证

MIT License

## 贡献

欢迎提交 Issue 和 Pull Request！

## 相关资源

- [EIP-1167: Minimal Proxy Contract](https://eips.ethereum.org/EIPS/eip-1167)
- [Uniswap V2 文档](https://docs.uniswap.org/contracts/v2/overview)
- [Foundry 文档](https://book.getfoundry.sh/)
