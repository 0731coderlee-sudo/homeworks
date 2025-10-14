// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./MemeToken.sol";

contract MemeFactory {
    address public implementation;  // 实现合约地址
    address public projectOwner;    // 项目方地址
    
    event MemeDeployed(address indexed memeToken, address indexed creator, string symbol);
    
    constructor() {
        implementation = address(new MemeToken());
        projectOwner = msg.sender;
    }
    
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
        
        // 费用分配：
        // - projectFee (1%): 给项目方（部署工厂合约的人，即"你"）作为平台手续费
        // - creatorFee (99%): 给 Meme 代币的创建者（调用 deployMeme 的人）
        // 
        // 示例：如果 Bob 支付 1 ETH 购买 Alice 创建的 Meme：
        //   - 项目方获得: 1 ETH × 1% = 0.01 ETH (平台费)
        //   - Alice 获得: 1 ETH × 99% = 0.99 ETH (创作收益)
        //   - Bob 获得: perMint 数量的代币
        uint256 projectFee = cost / 100;           // 1% 给项目方
        uint256 creatorFee = cost - projectFee;    // 99% 给 Meme 创建者
        
        // 铸造代币给购买者（msg.sender）
        token.mint(msg.sender, token.perMint());
        
        // 转账费用
        payable(projectOwner).transfer(projectFee);      // 项目方收取 1%
        payable(token.creator()).transfer(creatorFee);   // 创建者收取 99%
        
        // 退还多余的 ETH
        if (msg.value > cost) {
            payable(msg.sender).transfer(msg.value - cost);
        }
    }
}