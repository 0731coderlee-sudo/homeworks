// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/BaseERC721.sol";
import "../src/ttcoin.sol";
import "../src/NFTMarket.sol";

contract ImprovedContractsTest is Test {
    BaseERC721 public nft;
    ttcoin public token;
    NFTMarket public market;
    
    address public nftOwner;
    address public seller;
    address public buyer;
    
    uint256 public constant TOKEN_ID_1 = 168;
    uint256 public constant TOKEN_ID_2 = 169;
    uint256 public constant NFT_PRICE = 1000 * 10**18; // 1000 TTC
    uint256 public constant INITIAL_SUPPLY = 10000; // 10000 TTC

    event Listed(address indexed nft, uint256 indexed tokenId, address seller, uint256 price, address paymentToken);
    event Bought(address indexed nft, uint256 indexed tokenId, address buyer, uint256 price, address paymentToken);

    function setUp() public {
        // 设置测试账户
        nftOwner = makeAddr("nftOwner");
        seller = makeAddr("seller");  
        buyer = makeAddr("buyer");
        
        // 部署合约
        vm.prank(nftOwner);
        nft = new BaseERC721("TestNFT", "TNFT", "https://api.test.com/");
        
        vm.prank(seller);
        token = new ttcoin(INITIAL_SUPPLY, "TestCoin", "TTC");
        
        market = new NFTMarket(token);
        
        // 给买家转一些代币
        vm.prank(seller);
        token.transfer(buyer, INITIAL_SUPPLY * 10**18);
        
        // NFT owner mint NFT 给 seller
        vm.startPrank(nftOwner);
        nft.mint(seller, TOKEN_ID_1);
        nft.mint(seller, TOKEN_ID_2);
        vm.stopPrank();
    }

    // 测试改进后的合约基本功能
    function testImprovedNFTBasicFunctions() public {
        // 测试所有权
        assertEq(nft.owner(), nftOwner);
        
        // 测试NFT所有权
        assertEq(nft.ownerOf(TOKEN_ID_1), seller);
        assertEq(nft.ownerOf(TOKEN_ID_2), seller);
        
        // 测试余额
        assertEq(nft.balanceOf(seller), 2);
        
        // 测试只有owner能mint
        vm.expectRevert("BaseERC721: caller is not the owner");
        vm.prank(seller);
        nft.mint(seller, 170);
        
        // NFT owner可以mint
        vm.prank(nftOwner);
        nft.mint(seller, 170);
        assertEq(nft.ownerOf(170), seller);
    }
    
    // 测试批量mint功能
    function testBatchMint() public {
        uint256[] memory tokenIds = new uint256[](3);
        tokenIds[0] = 200;
        tokenIds[1] = 201;
        tokenIds[2] = 202;
        
        vm.prank(nftOwner);
        nft.batchMint(seller, tokenIds);
        
        assertEq(nft.ownerOf(200), seller);
        assertEq(nft.ownerOf(201), seller);
        assertEq(nft.ownerOf(202), seller);
        assertEq(nft.balanceOf(seller), 5); // setUp中2个(168,169) + batchMint的3个(200,201,202)
    }

    // 测试burn功能
    function testBurnFunction() public {
        // seller可以burn自己的NFT
        vm.prank(seller);
        nft.burn(TOKEN_ID_2);
        
        // 检查NFT已被销毁
        vm.expectRevert("ERC721: owner query for nonexistent token");
        nft.ownerOf(TOKEN_ID_2);
        
        assertEq(nft.balanceOf(seller), 1); // 2个减去1个被burn的
    }

    // 测试baseURI管理功能
    function testBaseURIManagement() public {
        string memory newURI = "https://new-api.test.com/";
        
        // 只有owner能设置baseURI
        vm.expectRevert("BaseERC721: caller is not the owner");
        vm.prank(seller);
        nft.setBaseURI(newURI);
        
        // owner可以设置
        vm.prank(nftOwner);
        nft.setBaseURI(newURI);
        
        assertEq(nft.baseURI(), newURI);
        assertEq(nft.tokenURI(TOKEN_ID_1), string(abi.encodePacked(newURI, "168")));
    }

    // 测试与NFTMarket的兼容性 - 传统购买模式
    function testTraditionalBuyingCompatibility() public {
        // 1. 卖家授权NFT给市场
        vm.prank(seller);
        nft.approve(address(market), TOKEN_ID_1);
        
        // 2. 卖家上架NFT
        vm.expectEmit(true, true, false, true);
        emit Listed(address(nft), TOKEN_ID_1, seller, NFT_PRICE, address(token));
        
        vm.prank(seller);
        market.list(address(nft), TOKEN_ID_1, NFT_PRICE);
        
        // 验证上架信息
        (address listingSeller, uint256 listingPrice, address paymentToken) = market.getListing(address(nft), TOKEN_ID_1);
        assertEq(listingSeller, seller);
        assertEq(listingPrice, NFT_PRICE);
        assertEq(paymentToken, address(token));
        
        // 验证NFT已转移到市场
        assertEq(nft.ownerOf(TOKEN_ID_1), address(market));
        
        // 3. 买家授权token给市场
        vm.prank(buyer);
        token.approve(address(market), NFT_PRICE);
        
        // 4. 买家购买NFT
        uint256 sellerBalanceBefore = token.balanceOf(seller);
        uint256 buyerBalanceBefore = token.balanceOf(buyer);
        
        vm.expectEmit(true, true, false, true);
        emit Bought(address(nft), TOKEN_ID_1, buyer, NFT_PRICE, address(token));
        
        vm.prank(buyer);
        market.buyNFT(address(nft), TOKEN_ID_1);
        
        // 验证交易结果
        assertEq(nft.ownerOf(TOKEN_ID_1), buyer);
        assertEq(token.balanceOf(seller), sellerBalanceBefore + NFT_PRICE);
        assertEq(token.balanceOf(buyer), buyerBalanceBefore - NFT_PRICE);
        
        // 验证上架记录已清除
        (address clearedSeller, uint256 clearedPrice, address clearedToken) = market.getListing(address(nft), TOKEN_ID_1);
        assertEq(clearedSeller, address(0));
        assertEq(clearedPrice, 0);
        assertEq(clearedToken, address(0));
    }

    // 测试与NFTMarket的兼容性 - 回调购买模式
    function testCallbackBuyingCompatibility() public {
        // 1. 卖家授权并上架NFT
        vm.startPrank(seller);
        nft.approve(address(market), TOKEN_ID_2);
        market.list(address(nft), TOKEN_ID_2, NFT_PRICE);
        vm.stopPrank();
        
        // 验证NFT已转移到市场
        assertEq(nft.ownerOf(TOKEN_ID_2), address(market));
        
        // 2. 使用callback模式购买
        uint256 sellerBalanceBefore = token.balanceOf(seller);
        uint256 buyerBalanceBefore = token.balanceOf(buyer);
        
        bytes memory data = abi.encode(address(nft), TOKEN_ID_2);
        
        vm.expectEmit(true, true, false, true);
        emit Bought(address(nft), TOKEN_ID_2, buyer, NFT_PRICE, address(token));
        
        vm.prank(buyer);
        token.transferWithCallback(address(market), NFT_PRICE, data);
        
        // 验证交易结果
        assertEq(nft.ownerOf(TOKEN_ID_2), buyer);
        assertEq(token.balanceOf(seller), sellerBalanceBefore + NFT_PRICE);
        assertEq(token.balanceOf(buyer), buyerBalanceBefore - NFT_PRICE);
        
        // 验证上架记录已清除
        (address clearedSeller, uint256 clearedPrice, address clearedToken) = market.getListing(address(nft), TOKEN_ID_2);
        assertEq(clearedSeller, address(0));
        assertEq(clearedPrice, 0);
        assertEq(clearedToken, address(0));
    }

    // 测试所有权转移功能
    function testOwnershipTransfer() public {
        address newOwner = makeAddr("newOwner");
        
        // 只有当前owner能转移所有权
        vm.expectRevert("BaseERC721: caller is not the owner");
        vm.prank(seller);
        nft.transferOwnership(newOwner);
        
        // 当前owner转移所有权
        vm.expectEmit(true, true, false, false);
        emit BaseERC721.OwnershipTransferred(nftOwner, newOwner);
        
        vm.prank(nftOwner);
        nft.transferOwnership(newOwner);
        
        assertEq(nft.owner(), newOwner);
        
        // 新owner可以mint
        vm.prank(newOwner);
        nft.mint(seller, 300);
        assertEq(nft.ownerOf(300), seller);
        
        // 原owner不能mint
        vm.expectRevert("BaseERC721: caller is not the owner");
        vm.prank(nftOwner);
        nft.mint(seller, 301);
    }

    // 测试完整的买卖流程兼容性
    function testCompleteMarketplaceFlow() public {
        // 模拟README中的完整流程
        
        // 1. NFT owner mint NFT给seller (已在setUp中完成)
        assertEq(nft.balanceOf(seller), 2); // TOKEN_ID_1, TOKEN_ID_2
        
        // 2. 卖家授权和上架
        vm.startPrank(seller);
        nft.approve(address(market), TOKEN_ID_1);
        market.list(address(nft), TOKEN_ID_1, NFT_PRICE);
        vm.stopPrank();
        
        // 3. 验证上架状态
        (address listingSeller, uint256 listingPrice, address paymentToken) = market.getListing(address(nft), TOKEN_ID_1);
        assertEq(listingSeller, seller);
        assertEq(listingPrice, NFT_PRICE);
        assertEq(paymentToken, address(token));
        assertEq(nft.ownerOf(TOKEN_ID_1), address(market));
        
        // 4. 买家使用callback模式购买
        bytes memory data = abi.encode(address(nft), TOKEN_ID_1);
        uint256 buyerBalanceBefore = token.balanceOf(buyer);
        uint256 sellerBalanceBefore = token.balanceOf(seller);
        
        vm.prank(buyer);
        token.transferWithCallback(address(market), NFT_PRICE, data);
        
        // 5. 验证交易完成
        assertEq(nft.ownerOf(TOKEN_ID_1), buyer);
        assertEq(token.balanceOf(buyer), buyerBalanceBefore - NFT_PRICE);
        assertEq(token.balanceOf(seller), sellerBalanceBefore + NFT_PRICE);
        
        // 6. 验证可以多次交易
        vm.startPrank(seller);
        nft.approve(address(market), TOKEN_ID_2);
        market.list(address(nft), TOKEN_ID_2, NFT_PRICE);
        vm.stopPrank();
        
        vm.startPrank(buyer);
        token.approve(address(market), NFT_PRICE);
        market.buyNFT(address(nft), TOKEN_ID_2);
        vm.stopPrank();
        
        assertEq(nft.ownerOf(TOKEN_ID_2), buyer);
        assertEq(nft.balanceOf(buyer), 2);
    }
}