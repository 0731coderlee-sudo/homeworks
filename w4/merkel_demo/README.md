### merkel-multicall-delegatecall-demo
```
完整流程动画演示

  用户发起交易
      │
      ▼
  multicall([data0, data1])
      │
      ├─ 循环 i=0 ──────────────────┐
      │                             │
      │  delegatecall(data0)        │
      │        │                    │
      │        ├─ 解码: permitPrePay(...)
      │        │                    │
      │        ├─ msg.sender = 用户 ✅
      │        │                    │
      │        └─ 执行授权 ✅        │
      │                             │
      ├─ 循环 i=1 ──────────────────┤
      │                             │
      │  delegatecall(data1)        │
      │        │                    │
      │        ├─ 解码: claimNFT(...)
      │        │                    │
      │        ├─ msg.sender = 用户 ✅
      │        │                    │
      │        ├─ 验证 Merkle ✅     │
      │        │                    │
      │        └─ 转账 + 转移NFT ✅  │
      │                             │
      └─ 返回 [result0, result1] ───┘
```