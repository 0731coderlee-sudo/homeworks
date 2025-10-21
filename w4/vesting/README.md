# Token Vesting Contract Demo

一个简单的 ERC20 代币线性释放(Vesting)合约实现。

## 合约功能

- **Cliff 期**: 12 个月(365天) - 在此期间不能释放任何代币
- **线性释放期**: 24 个月 - 从第 13 个月开始,按时间线性解锁
- **总锁定期**: 36 个月(1095天)
- **释放方式**: 调用 `release()` 方法释放已解锁的代币

## 文件结构

```
src/
├── TokenVesting.sol    # Vesting 合约
└── MockToken.sol       # 测试用 ERC20 代币

test/
└── TokenVesting.t.sol  # 测试文件

script/
└── Deploy.s.sol        # 部署脚本
```

## 快速开始

### 编译
```bash
forge build
```

### 测试
```bash
forge test -vv
```

### 部署(本地测试)
```bash
# 设置环境变量
export PRIVATE_KEY=your_private_key
export BENEFICIARY=beneficiary_address

# 部署到本地网络
forge script script/Deploy.s.sol:Deploy --fork-url http://localhost:8545 --broadcast
```

## 使用示例

```solidity
// 1. 部署代币合约
MockToken token = new MockToken();

// 2. 部署 Vesting 合约
TokenVesting vesting = new TokenVesting(
    beneficiaryAddress,     // 受益人地址
    address(token),         // ERC20 代币地址
    1_000_000 * 10**18     // 锁定数量: 100万代币
);

// 3. 转入代币到 Vesting 合约
token.transfer(address(vesting), 1_000_000 * 10**18);

// 4. 受益人调用 release() 释放代币(需要等到 cliff 期后)
vesting.release();
```

## 测试覆盖

- ✅ 初始状态检查
- ✅ Cliff 期前无法释放
- ✅ Cliff 期后可以释放
- ✅ 线性释放计算正确性
- ✅ 完整 Vesting 期后释放全部代币
- ✅ 多次释放功能
