# Chainlink Automation Demo - Bank Contract

这是一个使用 **Chainlink Automation** 实现自动化功能的智能合约演示项目。

## 项目概述

### Bank 合约

一个简单的银行合约，展示 Chainlink Automation 的自动化能力：

**核心功能：**
- ✅ 用户可以存款（`deposit()`）
- ✅ 用户可以提款（`withdraw()`）
- ✅ 当总存款达到阈值时，**自动转移一半资金**到指定地址
- ✅ Owner 可以动态修改阈值和接收地址

**自动化逻辑：**
1. 用户存款使总余额 >= 阈值
2. Chainlink Automation 节点检测到条件满足（`checkUpkeep` 返回 `true`）
3. 自动执行转账（`performUpkeep` 被调用）
4. 转移合约余额的一半到接收地址

---

## 快速开始

### 1. 安装依赖

```bash
# 安装 Chainlink 和 OpenZeppelin 合约
forge install smartcontractkit/chainlink-brownie-contracts --no-git
forge install OpenZeppelin/openzeppelin-contracts --no-git
```

### 2. 编译合约

```bash
forge build
```

### 3. 运行测试

```bash
# 运行所有测试
forge test

# 详细输出
forge test -vv

# 运行特定测试
forge test --match-test testDeposit

# Gas 报告
forge test --gas-report
```

### 4. 部署合约

#### 本地测试（Anvil）

```bash
# 启动本地节点
anvil

# 部署
forge script script/DeployBank.s.sol --rpc-url http://localhost:8545 --broadcast
```

#### Sepolia 测试网

```bash
# 设置环境变量
export SEPOLIA_RPC_URL="your_rpc_url"
export PRIVATE_KEY="your_private_key"
export ETHERSCAN_API_KEY="your_etherscan_api_key"

# 部署并验证
forge script script/DeployBank.s.sol \
  --rpc-url $SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --verify \
  --etherscan-api-key $ETHERSCAN_API_KEY
```

#### 自定义配置

```bash
# 设置自定义阈值和接收地址
export THRESHOLD=500000000000000000  # 0.5 ETH
export RECIPIENT=0xYourAddress

forge script script/DeployBank.s.sol --rpc-url sepolia --broadcast
```

---

## 注册 Chainlink Automation

部署合约后，需要在 Chainlink Automation 平台注册 Upkeep：

### 步骤

1. **访问 Chainlink Automation**
   - Sepolia: https://automation.chain.link/sepolia

2. **注册新的 Upkeep**
   - 点击 "Register new Upkeep"
   - 选择 "Custom logic"

3. **填写配置**
   ```
   Target contract address: [你的 Bank 合约地址]
   Upkeep name: Bank Auto Transfer
   Gas limit: 200000
   Starting balance: 5 LINK (或更多)
   Your email address: (可选)
   ```

4. **确认并资助**
   - 使用 LINK 代币为 Upkeep 充值
   - 确认注册

5. **验证**
   - 向合约存款，达到阈值
   - 观察 Chainlink 是否自动触发转账

### 获取 Sepolia LINK

- **Chainlink Faucet**: https://faucets.chain.link/sepolia
- **Alchemy Faucet**: https://www.alchemy.com/faucets/ethereum-sepolia

---

## 合约交互

### 使用 Cast 命令

```bash
# 设置合约地址
export BANK_ADDRESS=0xYourBankAddress

# 查询阈值
cast call $BANK_ADDRESS "threshold()(uint256)" --rpc-url sepolia

# 查询总存款
cast call $BANK_ADDRESS "totalDeposits()(uint256)" --rpc-url sepolia

# 存款 0.1 ETH
cast send $BANK_ADDRESS "deposit()" \
  --value 0.1ether \
  --rpc-url sepolia \
  --private-key $PRIVATE_KEY

# 查询用户余额
cast call $BANK_ADDRESS "balances(address)(uint256)" YOUR_ADDRESS --rpc-url sepolia

# 提款
cast send $BANK_ADDRESS "withdraw(uint256)" 50000000000000000 \
  --rpc-url sepolia \
  --private-key $PRIVATE_KEY

# 手动检查是否需要 upkeep
cast call $BANK_ADDRESS "checkUpkeep(bytes)(bool,bytes)" 0x --rpc-url sepolia

# Owner 修改阈值
cast send $BANK_ADDRESS "setThreshold(uint256)" 2000000000000000000 \
  --rpc-url sepolia \
  --private-key $PRIVATE_KEY
```

---

## 项目结构

```
.
├── src/
│   └── Bank.sol              # 银行合约（Chainlink Automation）
├── script/
│   └── DeployBank.s.sol      # 部署脚本
├── test/
│   └── Bank.t.sol            # 测试套件
├── lib/                      # 依赖库
├── foundry.toml              # Foundry 配置
└── README.md                 # 项目文档
```

---

## 测试覆盖

- ✅ 部署和初始化测试
- ✅ 存款/提款功能测试
- ✅ Chainlink `checkUpkeep` 逻辑测试
- ✅ Chainlink `performUpkeep` 执行测试
- ✅ Owner 权限管理测试
- ✅ 边界条件和安全测试
- ✅ Fuzz 测试

---

## 注意事项

⚠️ **这是一个演示合约**，主要用于学习 Chainlink Automation：

1. **简化设计**：为了突出自动化功能，余额管理做了简化
2. **测试网使用**：请先在测试网（Sepolia）部署和测试
3. **Gas 费用**：Chainlink Automation 会自动支付执行 `performUpkeep` 的 gas 费
4. **LINK 余额**：确保 Upkeep 有足够的 LINK 余额

---

## Foundry 工具链

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

- **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
- **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
- **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
- **Chisel**: Fast, utilitarian, and verbose solidity REPL.

### Documentation

https://book.getfoundry.sh/

---

## 资源链接

- **Chainlink Automation**: https://docs.chain.link/chainlink-automation
- **Chainlink Faucet**: https://faucets.chain.link/
- **Foundry Book**: https://book.getfoundry.sh/
- **Sepolia Etherscan**: https://sepolia.etherscan.io/

---

## License

MIT
