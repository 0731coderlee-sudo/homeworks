// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/MemeFactory.sol";
import "../src/MemeToken.sol";

contract MemeFactoryTest is Test {
    MemeFactory public factory;
    address public creator;
    address public buyer;
    
    // 允许接收 ETH
    receive() external payable {}
    
    function setUp() public {
        factory = new MemeFactory();
        creator = makeAddr("creator");
        buyer = makeAddr("buyer");
        vm.deal(creator, 100 ether);
        vm.deal(buyer, 100 ether);
    }
    
    function testDeployMeme() public {
        vm.prank(creator);
        address token = factory.deployMeme("PEPE", 1000 ether, 10 ether, 0.01 ether);
        
        MemeToken meme = MemeToken(token);
        assertEq(meme.symbol(), "PEPE");
        assertEq(meme.totalSupply(), 1000 ether);
        assertEq(meme.perMint(), 10 ether);
        assertEq(meme.price(), 0.01 ether);
        assertEq(meme.creator(), creator);
    }
    
    function testMintMeme() public {
        // 部署 Meme
        vm.prank(creator);
        address token = factory.deployMeme("DOGE", 100 ether, 10 ether, 0.01 ether);
        
        // 购买 Meme (10 ether tokens * 0.01 ether price = 0.1 ether cost)
        vm.prank(buyer);
        factory.mintMeme{value: 0.1 ether}(token);
        
        // 验证余额
        MemeToken meme = MemeToken(token);
        assertEq(meme.balanceOf(buyer), 10 ether);
        assertEq(meme.currentSupply(), 10 ether);
    }
    
    function testFeeDistribution() public {
        vm.prank(creator);
        address token = factory.deployMeme("SHIB", 100 ether, 10 ether, 0.1 ether);
        
        uint256 cost = 1 ether; // 10 ether * 0.1 ether = 1 ether
        uint256 projectFee = cost / 100; // 0.01 ether (1%)
        uint256 creatorFee = cost - projectFee; // 0.99 ether (99%)
        
        uint256 ownerBalanceBefore = factory.projectOwner().balance;
        uint256 creatorBalanceBefore = creator.balance;
        
        vm.prank(buyer);
        factory.mintMeme{value: cost}(token);
        
        // 验证费用按比例正确分配：1% 给项目方，99% 给创建者
        assertEq(factory.projectOwner().balance, ownerBalanceBefore + projectFee);
        assertEq(creator.balance, creatorBalanceBefore + creatorFee);
        
        console.log("Project fee (1%):", projectFee);
        console.log("Creator fee (99%):", creatorFee);
        console.log("Total cost:", cost);
    }
    
    function testPerMintCorrectAmount() public {
        vm.prank(creator);
        address token = factory.deployMeme("TEST", 1000 ether, 100 ether, 0.01 ether);
        
        MemeToken meme = MemeToken(token);
        
        // 第一次铸造
        vm.prank(buyer);
        factory.mintMeme{value: 1 ether}(token);
        assertEq(meme.balanceOf(buyer), 100 ether); // 正确铸造 perMint 数量
        assertEq(meme.currentSupply(), 100 ether);
        
        // 第二次铸造
        vm.prank(buyer);
        factory.mintMeme{value: 1 ether}(token);
        assertEq(meme.balanceOf(buyer), 200 ether); // 累积正确
        assertEq(meme.currentSupply(), 200 ether);
        
        console.log("Each mint amount:", meme.perMint());
        console.log("Total minted:", meme.currentSupply());
    }
    
    function testCannotExceedTotalSupply() public {
        vm.prank(creator);
        address token = factory.deployMeme("LIMIT", 100 ether, 60 ether, 0.01 ether);
        
        MemeToken meme = MemeToken(token);
        
        // 第一次铸造 60 ether
        vm.prank(buyer);
        factory.mintMeme{value: 0.6 ether}(token);
        assertEq(meme.currentSupply(), 60 ether);
        
        // 第二次铸造 60 ether 会超过 totalSupply (100 ether)，应该失败
        vm.prank(buyer);
        vm.expectRevert("Exceeds total supply");
        factory.mintMeme{value: 0.6 ether}(token);
        
        // 验证供应量没有变化
        assertEq(meme.currentSupply(), 60 ether);
        
        console.log("Total supply:", meme.totalSupply());
        console.log("Current supply:", meme.currentSupply());
        console.log("Remaining:", meme.totalSupply() - meme.currentSupply());
    }
    
    function testMultipleBuyersAndFeeDistribution() public {
        vm.prank(creator);
        address token = factory.deployMeme("MULTI", 1000 ether, 50 ether, 0.02 ether);
        
        address buyer2 = makeAddr("buyer2");
        vm.deal(buyer2, 100 ether);
        
        uint256 cost = 1 ether; // 50 ether * 0.02 ether = 1 ether
        
        uint256 ownerBalanceStart = factory.projectOwner().balance;
        uint256 creatorBalanceStart = creator.balance;
        
        // 买家1 购买
        vm.prank(buyer);
        factory.mintMeme{value: cost}(token);
        
        // 买家2 购买
        vm.prank(buyer2);
        factory.mintMeme{value: cost}(token);
        
        MemeToken meme = MemeToken(token);
        
        // 验证代币分配
        assertEq(meme.balanceOf(buyer), 50 ether);
        assertEq(meme.balanceOf(buyer2), 50 ether);
        assertEq(meme.currentSupply(), 100 ether);
        
        // 验证费用累积分配
        uint256 totalProjectFee = (cost * 2) / 100; // 2 次购买的 1%
        uint256 totalCreatorFee = cost * 2 - totalProjectFee; // 2 次购买的 99%
        
        assertEq(factory.projectOwner().balance, ownerBalanceStart + totalProjectFee);
        assertEq(creator.balance, creatorBalanceStart + totalCreatorFee);
        
        console.log("=== Multiple Buyers Test ===");
        console.log("Total project fee collected:", totalProjectFee);
        console.log("Total creator fee collected:", totalCreatorFee);
    }
    
    function testExcessPaymentRefund() public {
        vm.prank(creator);
        address token = factory.deployMeme("REFUND", 100 ether, 10 ether, 0.01 ether);
        
        uint256 cost = 0.1 ether; // 正确费用
        uint256 payment = 1 ether; // 支付过多
        
        uint256 buyerBalanceBefore = buyer.balance;
        
        vm.prank(buyer);
        factory.mintMeme{value: payment}(token);
        
        // 验证多余的 ETH 被退还
        assertEq(buyer.balance, buyerBalanceBefore - cost);
        
        console.log("Payment:", payment);
        console.log("Actual cost:", cost);
        console.log("Refunded:", payment - cost);
    }
}