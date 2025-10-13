# Anvil 测试账户信息

## 主要测试账户 (已分配代币和NFT)

### Account #0 (部署者)
- 地址: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
- 私钥: 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
- 余额: ~990,000 TTC (扣除分发的代币)

### Account #1 
- 地址: 0x70997970C51812dc3A010C7d01b50e0d17dc79C8
- 私钥: 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d
- 余额: 10,000 TTC + NFT #1

### Account #2
- 地址: 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC
- 私钥: 0x5de4111afa1a4b94908f83103c3ad2d63a3e2b3f84e6e79fe1b7c5cbd1e4c3a
- 余额: 10,000 TTC + NFT #2

### Account #3
- 地址: 0x90F79bf6EB2c4f870365E785982E1f101E93b906
- 私钥: 0x7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6
- 余额: 10,000 TTC + NFT #3

### Account #4-9 (其他测试账户)
- Account #4: 0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65
- Account #5: 0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc
- Account #6: 0x976EA74026E726554dB657fA54763abd0C3a0aa9
- Account #7: 0x14dC79964da2C08b23698B3D3cc7Ca32193d9955
- Account #8: 0x23618e81E3f5cdF7f54C3d65f7FBc0aBf5B21E8f
- Account #9: 0xa0Ee7A142d267C1f36714E4a8F75612F20a79720
- 余额: 每个账户 10,000 TTC

## 钱包设置

### 添加本地网络
- 网络名称: Anvil Local
- RPC URL: http://127.0.0.1:8545
- Chain ID: 31337
- 货币符号: ETH

### 建议使用的测试账户
推荐导入 Account #1-3 进行测试，因为它们有代币和NFT。

## 快速命令

```bash
# 重置环境
./reset-env.sh

# 启动前端
./start-frontend.sh

# 停止环境
./stop-env.sh

# 一键启动全部
./start-all.sh
```