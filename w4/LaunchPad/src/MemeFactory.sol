// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
// MemeFactory.sol 是一个代理合约工厂，用于部署 Meme 代币合约。
import "./MemeToken.sol";
import "./IUniswapV2Router.sol";

contract MemeFactory {
    address public implementation;  // 实现合约地址
    address public projectOwner;    // 项目方地址
    IUniswapV2Router public uniswapRouter; // Uniswap V2 Router

    // 事件：触发部署新的 Meme 代币
    event MemeDeployed(address indexed memeToken, address indexed creator, string symbol);
    event LiquidityAdded(address indexed token, uint256 tokenAmount, uint256 ethAmount, uint256 liquidity);
    event MemeBought(address indexed buyer, address indexed token, uint256 ethAmount, uint256 tokenAmount);

    // 构造函数：部署 MemeToken 合约并设置lanchpad项目方地址
    constructor(address _uniswapRouter) {
        implementation = address(new MemeToken()); // 部署 MemeToken 合约的逻辑合约 并且只需要部署这一次
        projectOwner = msg.sender;
        uniswapRouter = IUniswapV2Router(_uniswapRouter);
    }
    // 1. 部署 Meme 代币 的逻辑合约
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
            mstore(add(clone, 0x14), implementationBytes)//delegatecallz转发到逻辑合约地址
            /** 这段汇编代码就是在生成 45 字节的标准代理字节码：
  0x3d602d80600a3d3981f3363d3d373d3d3d363d73 + [实现合约地址 20字节] + 0x5af43d82803e903d91602b57fd5bf3 
    这 45 字节做的事情：
  1. 将所有 calldata 复制到内存
  2. 使用 delegatecall 调用实现合约
  3. 将返回数据复制回来并返回
    整体架构

  MemeFactory (工厂合约)
      │
      ├─ implementation (存储 MemeToken 逻辑合约地址)
      │
      └─ deployMeme() ──> 创建最小代理 ──> 每个代理指向 implementation
                                             │
                                             ├─ Proxy 1 (PEPE token)
                                             ├─ Proxy 2 (DOGE token)
                                             └─ Proxy 3 (SHIB token)
  */
            mstore(add(clone, 0x28), 0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000)
            proxy := create(0, clone, 0x37) //部署最小代理合约
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
        // - liquidityFee (5%): 用于添加 Uniswap 流动性
        // - creatorFee (95%): 给 Meme 代币的创建者（调用 deployMeme 的人）
        //
        // 示例：如果 Bob 支付 1 ETH 购买 Alice 创建的 Meme：
        //   - 流动性池: 1 ETH × 5% = 0.05 ETH + 相应的 Token
        //   - Alice 获得: 1 ETH × 95% = 0.95 ETH (创作收益)
        //   - Bob 获得: perMint 数量的代币
        //   - 项目方获得: LP Token（流动性凭证）
        uint256 liquidityFee = (cost * 5) / 100;      // 5% 用于流动性
        uint256 creatorFee = cost - liquidityFee;      // 95% 给 Meme 创建者

        // 铸造代币给购买者（msg.sender）
        token.mint(msg.sender, token.perMint());

        // 计算需要添加到流动性的 token 数量
        // 按照 mint price 计算：liquidityFee ETH 对应的 token 数量
        // price 是每个 token 的价格（单位：wei），所以 token数量 = ETH数量 / price * 1 ether
        uint256 liquidityTokenAmount = (liquidityFee * 1 ether) / token.price();

        // Mint token 给工厂合约自己
        token.mint(address(this), liquidityTokenAmount);

        // Approve Uniswap Router 使用 token
        token.approve(address(uniswapRouter), liquidityTokenAmount);

        // 添加流动性到 Uniswap（第一次按 mint price，后续按池子价格）
        (uint amountToken, uint amountETH, uint liquidity) = uniswapRouter.addLiquidityETH{value: liquidityFee}(
            tokenAddr,                  // token 地址
            liquidityTokenAmount,       // 期望添加的 token 数量
            0,                          // 最小 token 数量（0 = 无滑点保护）
            0,                          // 最小 ETH 数量（0 = 无滑点保护）
            projectOwner,               // LP token 接收地址（项目方）
            block.timestamp + 300       // deadline（5分钟后过期）
        );

        emit LiquidityAdded(tokenAddr, amountToken, amountETH, liquidity);

        // 转账给创建者
        payable(token.creator()).transfer(creatorFee);   // 创建者收取 95%

        // 退还多余的 ETH
        if (msg.value > cost) {
            payable(msg.sender).transfer(msg.value - cost);
        }
    }

    // 3. 从 Uniswap 购买 Meme 代币
    // 当 Uniswap 池子的价格优于 mint price 时，用户可以调用此函数
    function buyMeme(address tokenAddr) external payable {
        require(msg.value > 0, "Must send ETH");

        MemeToken token = MemeToken(tokenAddr);

        // 构建交易路径：WETH -> Token
        address[] memory path = new address[](2);
        path[0] = uniswapRouter.WETH();
        path[1] = tokenAddr;

        // 从 Uniswap 购买代币
        uint[] memory amounts = uniswapRouter.swapExactETHForTokens{value: msg.value}(
            0,                          // 最小获得数量（0 = 无滑点保护）
            path,                       // 交易路径
            msg.sender,                 // 代币接收地址
            block.timestamp + 300       // deadline（5分钟后过期）
        );

        // amounts[0] = 输入的 ETH 数量
        // amounts[1] = 获得的 Token 数量
        emit MemeBought(msg.sender, tokenAddr, amounts[0], amounts[1]);
    }

    // 4. 查询 Uniswap 价格
    // 返回用指定数量的 ETH 可以在 Uniswap 购买多少 Token
    function getUniswapPrice(address tokenAddr, uint256 ethAmount) external view returns (uint256) {
        address[] memory path = new address[](2);
        path[0] = uniswapRouter.WETH();
        path[1] = tokenAddr;

        try uniswapRouter.getAmountsOut(ethAmount, path) returns (uint[] memory amounts) {
            // amounts[0] = 输入的 ETH 数量
            // amounts[1] = 获得的 Token 数量
            return amounts[1];
        } catch {
            // 如果池子不存在或查询失败，返回 0
            return 0;
        }
    }

    // 5. 比较 Uniswap 价格和 Mint 价格
    // 返回 true 表示 Uniswap 价格更优（可以获得更多 token）
    function isUniswapBetter(address tokenAddr, uint256 ethAmount) external view returns (bool) {
        MemeToken token = MemeToken(tokenAddr);

        // 计算 mint 可以获得多少 token
        uint256 mintAmount = (ethAmount * 1 ether) / token.price();

        // 查询 Uniswap 可以获得多少 token
        address[] memory path = new address[](2);
        path[0] = uniswapRouter.WETH();
        path[1] = tokenAddr;

        try uniswapRouter.getAmountsOut(ethAmount, path) returns (uint[] memory amounts) {
            uint256 uniswapAmount = amounts[1];
            // 如果 Uniswap 能获得更多 token，说明价格更优
            return uniswapAmount > mintAmount;
        } catch {
            // 如果池子不存在，返回 false（使用 mint）
            return false;
        }
    }
}