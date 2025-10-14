# EIP-1167 最小代理 - Meme 代币发射平台
```
1. Bob 调用 mintMeme，支付 0.1 ETH
   (10 tokens × 0.01 ETH = 0.1 ETH)
   
2. 费用分配：
   - 项目方（你）获得：0.1 ETH × 1% = 0.001 ETH  
   - Alice（Meme创建者）获得：0.1 ETH × 99% = 0.099 ETH
   
3. Bob 获得 10 个 Meme 代币
```
### meme-factory 
- 提供deployMeme方法发射meme 
```
deployMeme 做了什么：

1. 使用 CREATE（不是 CREATE2）opcode
2. 传入的是 EIP-1167 最小代理的字节码（45字节），而不是逻辑合约的完整字节码
3. 这 45 字节的代理字节码包含了对 memetoken(实现合约/逻辑合约) 地址的引用
```
- 提供mintMeme方法 平台用户可以ment指定memetoken
```
    // 1. 部署 Meme 代币
    function deployMeme(
        string memory symbol,
        uint256 totalSupply,
        uint256 perMint,
        uint256 price
    ) external returns (address) {
        // 创建最小代理（EIP-1167）
        bytes20 implementationBytes = bytes20(implementation);
        address proxy;
        
        assembly {
            let clone := mload(0x40)
            mstore(clone, 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000)
            mstore(add(clone, 0x14), implementationBytes)
            mstore(add(clone, 0x28), 0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000)
            proxy := create(0, clone, 0x37)
        }
        
        // 初始化代理合约
        MemeToken(proxy).initialize(symbol, totalSupply, perMint, price, msg.sender);
        
        emit MemeDeployed(proxy, msg.sender, symbol);
        return proxy;
    }
    
    // 2. 铸造 Meme 代币
    function mintMeme(address tokenAddr) external payable {
        MemeToken token = MemeToken(tokenAddr);
        
        // 计算费用：perMint 数量 * price (考虑到 perMint 有 18 位小数)
        uint256 cost = (token.perMint() * token.price()) / 1 ether;
        require(msg.value >= cost, "Insufficient payment");
        
        // 费用分配：1% 给项目方，99% 给创建者
        uint256 projectFee = cost / 100;
        uint256 creatorFee = cost - projectFee;
        
        // 铸造代币
        token.mint(msg.sender, token.perMint());
        
        // 转账费用
        payable(projectOwner).transfer(projectFee);
        payable(token.creator()).transfer(creatorFee);
        
        // 退还多余的 ETH
        if (msg.value > cost) {
            payable(msg.sender).transfer(msg.value - cost);
        }
    }
```

### memeToken
- 定义了token的最小标准接口
- 定义了初始化函数（代替构造函数）// 方便工厂合约创建合约后调用
- 定义了mint方法
```
    // 铸造代币
    function mint(address to, uint256 amount) external {
        require(currentSupply + amount <= totalSupply, "Exceeds total supply");
        balanceOf[to] += amount;
        currentSupply += amount;
        emit Transfer(address(0), to, amount);
    }
```