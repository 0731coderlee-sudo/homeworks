
 ✅ 测试完成清单

  1. V2 -> V3 升级测试

  - ✅ V2 状态验证
  - ✅ 成功升级到 V3
  - ✅ V3 功能初始化
  - ✅ 支付代币配置
  - ✅ 交易：https://sepolia.etherscan.io/tx/0x789a71e3aad01542592318bb1b9507c5ecf0b5f94e91e906bf72519165ef0b3c

  1. V3 setApprovalForAll 签名上架测试

  - ✅ 市场版本验证（3.0.0）
  - ✅ NFT 铸造（Token ID #3）
  - ✅ 一次性授权成功
  - ✅ EIP-712 签名生成正确
  - ✅ 签名上架成功
  - ✅ 上架信息验证通过
  - ✅ Nonce 正确递增（0 -> 1）
  - ✅ 交易： https://sepolia.etherscan.io/tx/0xaf9e1131b3615d0be87e0e77bb89ec7ef303a8bd0b6327898bb4579af4b76f69

  🎯 核心成果

  新部署的合约地址：
  代理合约（用户交互）:   0x358D663742D3141188D0A2a4e871250e75835046
  V2 实现:               0x28AD573864Af6F3d66d033D16392AF09cEB88eA3
  V3 实现:               0xB473B952d9Abb655922eaCCe4DE0e66Ddf6a605C
  BaseERC721:           0xD1689165740CD727fba08a9F721bB6fCa297fD1F
  TTCoin:               0xd499Ac1FBfa849640Ec92d26a8bA67d39019360a

  可用命令： use /script/TestSignatureListing.ts
  npm run test:upgrade     # 测试 V2 -> V3 升级
  npm run test:signature   # 测试签名上架功能

