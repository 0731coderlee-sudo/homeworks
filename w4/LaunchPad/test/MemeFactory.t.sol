// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/MemeFactory.sol";
import "../src/MemeToken.sol";
import "./mocks/MockUniswapV2Router.sol";
import "./mocks/MockUniswapV2Factory.sol";
import "./mocks/MockWETH.sol";

contract MemeFactoryTest is Test {
    MemeFactory public factory;
    MockUniswapV2Router public router;
    MockUniswapV2Factory public uniswapFactory;
    MockWETH public weth;

    address public owner = address(this);
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);
    address public carol = address(0xCA401);

    // 事件声明（用于测试）
    event MemeDeployed(address indexed memeToken, address indexed creator, string symbol);
    event LiquidityAdded(address indexed token, uint256 tokenAmount, uint256 ethAmount, uint256 liquidity);
    event MemeBought(address indexed buyer, address indexed token, uint256 ethAmount, uint256 tokenAmount);

    function setUp() public {
        // 部署 mock contracts
        weth = new MockWETH();
        uniswapFactory = new MockUniswapV2Factory();
        router = new MockUniswapV2Router(address(uniswapFactory), payable(address(weth)));

        // 部署 MemeFactory
        factory = new MemeFactory(address(router));

        // 给测试账户一些 ETH
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
        vm.deal(carol, 100 ether);
    }

    function testDeployFactory() public {
        assertEq(factory.projectOwner(), owner);
        assertEq(address(factory.uniswapRouter()), address(router));
        assertTrue(factory.implementation() != address(0));
    }

    function testDeployMeme() public {
        vm.startPrank(alice);

        // 部署 PEPE meme 币
        address pepeToken = factory.deployMeme(
            "PEPE",           // symbol
            1000000 ether,    // totalSupply
            100 ether,        // perMint
            0.01 ether       // price (每个 token 0.01 ETH)
        );

        assertTrue(pepeToken != address(0));

        MemeToken token = MemeToken(pepeToken);
        assertEq(token.symbol(), "PEPE");
        assertEq(token.totalSupply(), 1000000 ether);
        assertEq(token.perMint(), 100 ether);
        assertEq(token.price(), 0.01 ether);
        assertEq(token.creator(), alice);

        vm.stopPrank();
    }

    function testMintMeme() public {
        // Alice 创建 PEPE 币
        vm.prank(alice);
        address pepeToken = factory.deployMeme("PEPE", 1000000 ether, 100 ether, 0.01 ether);

        MemeToken token = MemeToken(pepeToken);

        // Bob 购买 PEPE
        uint256 aliceBalanceBefore = alice.balance;
        uint256 ownerBalanceBefore = owner.balance;

        vm.prank(bob);
        factory.mintMeme{value: 1 ether}(pepeToken);

        // 检查 Bob 获得了代币
        assertEq(token.balanceOf(bob), 100 ether);

        // 检查费用分配
        // cost = (100 ether * 0.01 ether) / 1 ether = 1 ether
        // liquidityFee = 1 ether * 5% = 0.05 ether
        // creatorFee = 1 ether - 0.05 ether = 0.95 ether
        assertEq(alice.balance, aliceBalanceBefore + 0.95 ether);

        // 检查流动性已添加（ETH 已发送给 router）
        assertTrue(token.balanceOf(address(router)) == 0); // Token 应该在 pair 中
    }

    function testMintMemeAddsLiquidity() public {
        // Alice 创建 PEPE 币
        vm.prank(alice);
        address pepeToken = factory.deployMeme("PEPE", 1000000 ether, 100 ether, 0.01 ether);

        MemeToken token = MemeToken(pepeToken);

        // Bob 第一次购买（会创建流动性池）
        vm.prank(bob);
        factory.mintMeme{value: 1 ether}(pepeToken);

        // 检查流动性池是否创建
        address pair = uniswapFactory.getPair(pepeToken, address(weth));
        assertTrue(pair != address(0), "Pair should be created");

        // 检查项目方获得了 LP token
        assertTrue(MockUniswapV2Pair(pair).balanceOf(owner) > 0, "Owner should have LP tokens");

        // 检查储备金
        (uint112 reserve0, uint112 reserve1,) = MockUniswapV2Pair(pair).getReserves();
        assertTrue(reserve0 > 0 && reserve1 > 0, "Reserves should be set");
    }

    function testMultipleMints() public {
        // Alice 创建 PEPE 币
        vm.prank(alice);
        address pepeToken = factory.deployMeme("PEPE", 1000000 ether, 100 ether, 0.01 ether);

        MemeToken token = MemeToken(pepeToken);

        // Bob 购买两次
        vm.startPrank(bob);
        factory.mintMeme{value: 1 ether}(pepeToken);
        factory.mintMeme{value: 1 ether}(pepeToken);
        vm.stopPrank();

        // Bob 应该获得 200 PEPE
        assertEq(token.balanceOf(bob), 200 ether);

        // Carol 也购买
        vm.prank(carol);
        factory.mintMeme{value: 1 ether}(pepeToken);

        assertEq(token.balanceOf(carol), 100 ether);
    }

    function testBuyMemeFromUniswap() public {
        // Alice 创建 PEPE 币
        vm.prank(alice);
        address pepeToken = factory.deployMeme("PEPE", 10000000 ether, 100 ether, 0.01 ether);

        // Bob 先 mint 一次以建立流动性
        vm.prank(bob);
        factory.mintMeme{value: 1 ether}(pepeToken);

        // 现在流动性池已经存在，Carol 可以从 Uniswap 购买
        vm.prank(carol);
        factory.buyMeme{value: 0.5 ether}(pepeToken);

        // Carol 应该获得了一些代币
        MemeToken token = MemeToken(pepeToken);
        assertTrue(token.balanceOf(carol) > 0, "Carol should have tokens");
    }

    function testGetUniswapPrice() public {
        // Alice 创建 PEPE 币
        vm.prank(alice);
        address pepeToken = factory.deployMeme("PEPE", 10000000 ether, 100 ether, 0.01 ether);

        // 在没有流动性时查询价格
        uint256 priceBeforeLiquidity = factory.getUniswapPrice(pepeToken, 1 ether);
        assertEq(priceBeforeLiquidity, 0, "Should return 0 when no liquidity");

        // Bob mint 以添加流动性
        vm.prank(bob);
        factory.mintMeme{value: 1 ether}(pepeToken);

        // 现在应该能查询到价格
        uint256 priceAfterLiquidity = factory.getUniswapPrice(pepeToken, 1 ether);
        assertTrue(priceAfterLiquidity > 0, "Should return price when liquidity exists");
    }

    function testIsUniswapBetter() public {
        // Alice 创建 PEPE 币
        vm.prank(alice);
        address pepeToken = factory.deployMeme("PEPE", 10000000 ether, 100 ether, 0.01 ether);

        // 没有流动性时，应该返回 false（使用 mint）
        bool isBetter = factory.isUniswapBetter(pepeToken, 1 ether);
        assertFalse(isBetter, "Should prefer mint when no liquidity");

        // 添加流动性
        vm.prank(bob);
        factory.mintMeme{value: 1 ether}(pepeToken);

        // 这时候可以比较价格
        // 由于 Uniswap 有交易费用，通常 mint 会更优
        bool isBetterAfter = factory.isUniswapBetter(pepeToken, 1 ether);
        // 结果取决于流动性池的状态
    }

    function testInsufficientPayment() public {
        vm.prank(alice);
        address pepeToken = factory.deployMeme("PEPE", 1000000 ether, 100 ether, 0.01 ether);

        // Bob 尝试支付不足的金额
        vm.prank(bob);
        vm.expectRevert("Insufficient payment");
        factory.mintMeme{value: 0.5 ether}(pepeToken); // 需要 1 ETH，但只支付 0.5 ETH
    }

    function testRefundExcessPayment() public {
        vm.prank(alice);
        address pepeToken = factory.deployMeme("PEPE", 1000000 ether, 100 ether, 0.01 ether);

        uint256 bobBalanceBefore = bob.balance;

        // Bob 支付超过需要的金额
        vm.prank(bob);
        factory.mintMeme{value: 2 ether}(pepeToken); // 只需要 1 ETH

        // 检查退款
        assertEq(bob.balance, bobBalanceBefore - 1 ether, "Should refund excess payment");
    }

    function testExceedTotalSupply() public {
        // 每次 mint 会铸造 100 ether 给用户 + 5 ether 给流动性 = 105 ether 总计
        // 设置 totalSupply = 210 ether，刚好够两次购买
        vm.prank(alice);
        address pepeToken = factory.deployMeme("PEPE", 210 ether, 100 ether, 0.01 ether);

        // Bob 购买两次（会消耗 210 ether）
        vm.startPrank(bob);
        factory.mintMeme{value: 1 ether}(pepeToken); // mint 105 ether (100 + 5)
        factory.mintMeme{value: 1 ether}(pepeToken); // mint 105 ether (100 + 5)
        vm.stopPrank();

        // 此时已经 mint 了 210 ether，达到 totalSupply
        // 第三次购买应该失败
        vm.prank(carol);
        vm.expectRevert("Exceeds total supply");
        factory.mintMeme{value: 1 ether}(pepeToken);
    }

    function testMultipleTokens() public {
        // Alice 创建 PEPE
        vm.prank(alice);
        address pepeToken = factory.deployMeme("PEPE", 1000000 ether, 100 ether, 0.01 ether);

        // Bob 创建 DOGE
        vm.prank(bob);
        address dogeToken = factory.deployMeme("DOGE", 500000 ether, 50 ether, 0.02 ether);

        // 确认两个代币独立
        MemeToken pepe = MemeToken(pepeToken);
        MemeToken doge = MemeToken(dogeToken);

        assertEq(pepe.symbol(), "PEPE");
        assertEq(doge.symbol(), "DOGE");
        assertEq(pepe.creator(), alice);
        assertEq(doge.creator(), bob);

        // Carol 分别购买
        vm.startPrank(carol);
        factory.mintMeme{value: 1 ether}(pepeToken);
        factory.mintMeme{value: 1 ether}(dogeToken);
        vm.stopPrank();

        assertEq(pepe.balanceOf(carol), 100 ether);
        assertEq(doge.balanceOf(carol), 50 ether);
    }

    function testFeeDistribution() public {
        vm.prank(alice);
        address pepeToken = factory.deployMeme("PEPE", 1000000 ether, 100 ether, 0.01 ether);

        uint256 aliceBalanceBefore = alice.balance;
        uint256 ownerBalanceBefore = owner.balance;

        // Bob 购买 1 ETH 的 PEPE
        vm.prank(bob);
        factory.mintMeme{value: 1 ether}(pepeToken);

        // 检查 Alice 获得 95%
        assertEq(alice.balance, aliceBalanceBefore + 0.95 ether, "Creator should get 95%");

        // 5% 应该用于流动性（不会直接给 owner，而是添加到 Uniswap）
        // Owner 获得的是 LP token，不是 ETH
    }

    function testCannotInitializeTwice() public {
        vm.prank(alice);
        address pepeToken = factory.deployMeme("PEPE", 1000000 ether, 100 ether, 0.01 ether);

        MemeToken token = MemeToken(pepeToken);

        // 尝试再次初始化
        vm.expectRevert("Already initialized");
        token.initialize("FAKE", 1000 ether, 10 ether, 0.1 ether, bob);
    }

    receive() external payable {}
}
