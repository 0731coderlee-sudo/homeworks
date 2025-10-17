# NFTMarket Gas Report V1

## 测试环境
- 测试框架: Foundry
- 测试文件: test/MultiTokenMarketTest.t.sol
- 测试时间: 2025-10-18
- 通过测试: 9/9

## 1. NFTMarket 合约

### 部署成本
| 指标 | 数值 |
|------|------|
| Deployment Cost | 1,751,690 gas |
| Deployment Size | 8,066 bytes |

### 函数 Gas 消耗统计

#### addSupportedToken - 添加支持的代币
| 统计项 | Gas 消耗 |
|--------|---------|
| Min | 24,377 |
| Average | 45,437 |
| Median | 47,544 |
| Max | 47,544 |
| Calls | 11 |

#### buyNFT - 购买 NFT
| 统计项 | Gas 消耗 |
|--------|---------|
| Min | 29,175 |
| Average | 73,699 |
| Median | 88,714 |
| Max | 106,436 |
| Calls | 8 |

**说明**: buyNFT 是最常用的购买函数，平均消耗约 73.7k gas

#### getListing - 获取上架信息
| 统计项 | Gas 消耗 |
|--------|---------|
| Min | 7,930 |
| Average | 7,930 |
| Median | 7,930 |
| Max | 7,930 |
| Calls | 3 |

**说明**: 纯查询函数，gas 消耗稳定且低

#### isTokenSupported - 检查代币是否被支持
| 统计项 | Gas 消耗 |
|--------|---------|
| Min | 2,937 |
| Average | 2,937 |
| Median | 2,937 |
| Max | 2,937 |
| Calls | 5 |

**说明**: 简单查询，gas 消耗极低

#### list - 上架 NFT（默认 ttcoin）
| 统计项 | Gas 消耗 |
|--------|---------|
| Min | 25,002 |
| Average | 79,855 |
| Median | 76,499 |
| Max | 141,420 |
| Calls | 4 |

**说明**: 首次上架会消耗更多 gas（存储初始化），后续上架消耗较低

#### listWithToken - 上架 NFT（指定支付代币）
| 统计项 | Gas 消耗 |
|--------|---------|
| Min | 25,800 |
| Average | 117,658 |
| Median | 139,896 |
| Max | 139,896 |
| Calls | 13 |

**说明**: 指定代币上架比默认上架稍微消耗更多 gas

#### removeSupportedToken - 移除支持的代币
| 统计项 | Gas 消耗 |
|--------|---------|
| Min | 25,653 |
| Average | 25,653 |
| Median | 25,653 |
| Max | 25,653 |
| Calls | 1 |

**说明**: 单次调用，消耗稳定

## 2. BaseERC721 合约

### 部署成本
| 指标 | 数值 |
|------|------|
| Deployment Cost | 3,897,928 gas |
| Deployment Size | 19,102 bytes |

### 函数 Gas 消耗统计

#### approve - 授权 NFT
| 统计项 | Gas 消耗 |
|--------|---------|
| Min | 49,176 |
| Average | 49,176 |
| Median | 49,176 |
| Max | 49,176 |
| Calls | 16 |

#### mint - 铸造 NFT
| 统计项 | Gas 消耗 |
|--------|---------|
| Min | 54,217 |
| Average | 59,917 |
| Median | 54,217 |
| Max | 71,317 |
| Calls | 27 |

**说明**: 首次铸造给新地址时消耗更多 gas（需要初始化 balance）

#### ownerOf - 查询 NFT 拥有者
| 统计项 | Gas 消耗 |
|--------|---------|
| Min | 2,921 |
| Average | 2,921 |
| Median | 2,921 |
| Max | 2,921 |
| Calls | 19 |

## 3. ttcoin 合约（ERC20 扩展）

### 部署成本
| 指标 | 数值 |
|------|------|
| Deployment Cost | 1,722,311 gas |
| Deployment Size | 9,271 bytes |

### 函数 Gas 消耗统计

#### approve - 授权代币
| 统计项 | Gas 消耗 |
|--------|---------|
| Min | 46,756 |
| Average | 46,756 |
| Median | 46,756 |
| Max | 46,756 |
| Calls | 1 |

#### balanceOf - 查询余额
| 统计项 | Gas 消耗 |
|--------|---------|
| Min | 2,825 |
| Average | 2,825 |
| Median | 2,825 |
| Max | 2,825 |
| Calls | 6 |

#### transfer - 转账
| 统计项 | Gas 消耗 |
|--------|---------|
| Min | 53,620 |
| Average | 53,620 |
| Median | 53,620 |
| Max | 53,620 |
| Calls | 9 |

#### transferWithCallback - 带回调的转账
| 统计项 | Gas 消耗 |
|--------|---------|
| Min | 69,828 |
| Average | 87,239 |
| Median | 85,004 |
| Max | 109,119 |
| Calls | 4 |

**说明**: 带回调功能比普通转账多消耗约 30k+ gas，因为需要调用接收方的 tokensReceived 函数

## 4. TestERC20 合约（标准 ERC20）

### 部署成本
| 指标 | 数值 |
|------|------|
| Deployment Cost | 930,761 gas |
| Deployment Size | 5,227 bytes |

### 函数 Gas 消耗统计

#### approve
| 统计项 | Gas 消耗 |
|--------|---------|
| Min | 29,646 |
| Average | 43,876 |
| Median | 46,722 |
| Max | 46,722 |
| Calls | 6 |

#### balanceOf
| 统计项 | Gas 消耗 |
|--------|---------|
| Min | 2,824 |
| Average | 2,824 |
| Median | 2,824 |
| Max | 2,824 |
| Calls | 4 |

#### transfer
| 统计项 | Gas 消耗 |
|--------|---------|
| Min | 52,374 |
| Average | 52,380 |
| Median | 52,380 |
| Max | 52,386 |
| Calls | 18 |

## 5. Gas 优化建议

### 高优先级优化
1. **list/listWithToken 函数**:
   - 当前平均消耗: 79,855 - 117,658 gas
   - 建议: 考虑使用更紧凑的数据结构存储 Listing

2. **buyNFT 函数**:
   - 当前平均消耗: 73,699 gas
   - 建议: 优化 NFT 转移和 token 转账的顺序，减少状态变更

### 中优先级优化
3. **BaseERC721 部署成本**:
   - 当前: 3,897,928 gas (19,102 bytes)
   - 建议: 考虑移除不常用的功能到单独的合约

### 对比分析
- ttcoin (9,271 bytes) vs TestERC20 (5,227 bytes)
- ttcoin 的 callback 功能增加了约 44% 的合约大小
- transferWithCallback 比普通 transfer 多消耗约 60% 的 gas

## 6. 总结

### 核心功能 Gas 消耗
- 上架 NFT: ~80k - 118k gas
- 购买 NFT: ~74k gas
- NFT 铸造: ~60k gas
- 代币转账: ~53k gas
- 带回调转账: ~87k gas

### 部署成本总计
| 合约 | Gas 消耗 |
|------|---------|
| NFTMarket | 1,751,690 |
| BaseERC721 | 3,897,928 |
| ttcoin | 1,722,311 |
| 总计 | 7,371,929 |

整体来看，NFTMarket 合约的 gas 消耗处于合理范围内，主要的 gas 消耗来自于 NFT 的转移和状态存储。
