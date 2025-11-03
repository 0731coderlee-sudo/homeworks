demo
- 你的 Bundle → Flashbots Relay → MEV-Boost → 验证者
- Bundle是否在竞价中胜出
- 验证者是否恰好出块
```
========== Flashbots Bundle 交易开始 ==========

✅ 连接到 RPC 提供商: https://sepolia.infura.io/v3/fb5a7828745a4c5a829fd0b3384bea19
✅ Flashbots Provider 创建成功

📊 当前区块高度: 9550974
💼 钱包地址: 0x4A2578679C9a9901844380C7340e074045e75853
💰 钱包余额: 1.633537401705983916 ETH
📝 NFT 合约地址: 0xC6Da2c0D02d6F24D9b64380629575f5Da9A2aB6A

========== Gas 价格策略 ==========

当前网络 Gas 价格:
  maxFeePerGas: 1.00000002 gwei
  maxPriorityFeePerGas: 1.0 gwei

💰 Bundle 使用（3倍提升）:
  maxFeePerGas: 3.00000006 gwei
  maxPriorityFeePerGas: 3.0 gwei

💡 策略: 更高的 priority fee = 更吸引验证者 = 更高上链概率

========== 构建 Bundle 交易 ==========


💎 启用直接小费策略
   小费金额: 0.001 ETH
   说明: 直接转账给区块构建者，提高 Bundle 优先级

📦 Bundle 包含 3 笔交易:
  💰 直接小费给验证者
  1️⃣  startPresale()
  2️⃣  participateInPresale()

💰 Bundle 预估价值:
   直接小费: 0.001 ETH
   Gas 费用: 0.000450000009 ETH (估算)
   总价值: 0.001450000009 ETH

⏳ 签名 Bundle 交易...

========== 交易哈希 ==========

交易 1 哈希: 0xfeb0de8b0935559bc54171c1a43fe31dec6dbd1e7365e796a87e6aabd197e430
交易 2 哈希: 0x702999fc21950628c1d05648d40c5bcebd1e8b72e98d013db3f7456b7b50c5a2
交易 3 哈希: 0x8f49b65d45a9f55adcda895a2a17cc3d198fb93b7230523e86b00bd19c787bfe

========== 模拟结果 ==========

{
  "bundleGasPrice": "3000000000",
  "bundleHash": "0x0464f6d678c7b2455ae2c8fa0478f72922a378539215cd3e2bdc1d13829ad7aa",
  "coinbaseDiff": "190743000000000",
  "ethSentToCoinbase": "0",
  "gasFees": "190743000000000",
  "results": [
    {
      "coinbaseDiff": "63000000000000",
      "ethSentToCoinbase": "0",
      "fromAddress": "0x4a2578679c9a9901844380c7340e074045e75853",
      "gasFees": "63000000000000",
      "gasPrice": "3000000000",
      "gasUsed": 21000,
      "toAddress": "0x690b9a9e9aa1c9db991c7721a92d351db4fac990",
      "txHash": "0xfeb0de8b0935559bc54171c1a43fe31dec6dbd1e7365e796a87e6aabd197e430",
      "value": "0x"
    },
    {
      "coinbaseDiff": "63825000000000",
      "ethSentToCoinbase": "0",
      "fromAddress": "0x4a2578679c9a9901844380c7340e074045e75853",
      "gasFees": "63825000000000",
      "gasPrice": "3000000000",
      "gasUsed": 21275,
      "revert": "0x",
      "toAddress": "0xc6da2c0d02d6f24d9b64380629575f5da9a2ab6a",
      "txHash": "0x702999fc21950628c1d05648d40c5bcebd1e8b72e98d013db3f7456b7b50c5a2",
      "value": null
    },
    {
      "coinbaseDiff": "63918000000000",
      "ethSentToCoinbase": "0",
      "fromAddress": "0x4a2578679c9a9901844380c7340e074045e75853",
      "gasFees": "63918000000000",
      "gasPrice": "3000000000",
      "gasUsed": 21306,
      "revert": "0x",
      "toAddress": "0xc6da2c0d02d6f24d9b64380629575f5da9a2ab6a",
      "txHash": "0x8f49b65d45a9f55adcda895a2a17cc3d198fb93b7230523e86b00bd19c787bfe",
      "value": null
    }
  ],
  "stateBlockNumber": 9550974,
  "totalGasUsed": 63581,
  "firstRevert": {
    "coinbaseDiff": "63825000000000",
    "ethSentToCoinbase": "0",
    "fromAddress": "0x4a2578679c9a9901844380c7340e074045e75853",
    "gasFees": "63825000000000",
    "gasPrice": "3000000000",
    "gasUsed": 21275,
    "revert": "0x",
    "toAddress": "0xc6da2c0d02d6f24d9b64380629575f5da9a2ab6a",
    "txHash": "0x702999fc21950628c1d05648d40c5bcebd1e8b72e98d013db3f7456b7b50c5a2",
    "value": null
  }
}

```