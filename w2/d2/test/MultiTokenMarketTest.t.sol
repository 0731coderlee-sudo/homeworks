// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/BaseERC721.sol";
import "../src/ttcoin.sol";
import "../src/NFTMarket.sol";

// 创建一个简单的ERC20代币用于测试
contract TestERC20 {
    string public name;
    string public symbol;
    uint8 public decimals = 18;
    uint256 public totalSupply;
    
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    
    constructor(string memory _name, string memory _symbol, uint256 _supply) {
        name = _name;
        symbol = _symbol;
        totalSupply = _supply * 10**18;
        balanceOf[msg.sender] = totalSupply;
    }
    
    function transfer(address to, uint256 amount) external returns (bool) {
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }
    
    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        require(balanceOf[from] >= amount, "Insufficient balance");
        require(allowance[from][msg.sender] >= amount, "Allowance exceeded");
        
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        allowance[from][msg.sender] -= amount;
        
        emit Transfer(from, to, amount);
        return true;
    }
    
    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }
}

contract MultiTokenMarketTest is Test {
    BaseERC721 public nft;
    ttcoin public ttcToken;
    TestERC20 public usdcToken;
    TestERC20 public daiToken;
    NFTMarket public market;
    
    address public marketOwner;
    address public nftOwner;
    address public seller;
    address public buyer1;
    address public buyer2;
    
    uint256 public constant TOKEN_ID_1 = 1;
    uint256 public constant TOKEN_ID_2 = 2;
    uint256 public constant TOKEN_ID_3 = 3;
    
    uint256 public constant TTC_PRICE = 1000 * 10**18;
    uint256 public constant USDC_PRICE = 100 * 10**18;
    uint256 public constant DAI_PRICE = 500 * 10**18;

    function setUp() public {
        marketOwner = makeAddr("marketOwner");
        nftOwner = makeAddr("nftOwner");
        seller = makeAddr("seller");
        buyer1 = makeAddr("buyer1");
        buyer2 = makeAddr("buyer2");
        
        // 部署代币
        vm.prank(seller);
        ttcToken = new ttcoin(10000, "TestCoin", "TTC");
        
        vm.prank(buyer1);
        usdcToken = new TestERC20("USD Coin", "USDC", 10000);
        
        vm.prank(buyer2);
        daiToken = new TestERC20("DAI Stablecoin", "DAI", 10000);
        
        // 部署NFT
        vm.prank(nftOwner);
        nft = new BaseERC721("MultiTokenNFT", "MTNFT", "https://api.test.com/");
        
        // 部署市场
        vm.prank(marketOwner);
        market = new NFTMarket(ttcToken);
        
        // Mint NFTs
        vm.startPrank(nftOwner);
        nft.mint(seller, TOKEN_ID_1);
        nft.mint(seller, TOKEN_ID_2);
        nft.mint(seller, TOKEN_ID_3);
        vm.stopPrank();
        
        // 分发代币给买家
        vm.prank(seller);
        ttcToken.transfer(buyer1, 5000 * 10**18);
        
        vm.prank(buyer1);
        usdcToken.transfer(buyer2, 1000 * 10**18);
        
        vm.prank(buyer2);
        daiToken.transfer(buyer1, 2000 * 10**18);
    }

    // 测试添加支持的代币
    function testAddSupportedTokens() public {
        // 只有owner可以添加代币
        vm.expectRevert("Not owner");
        vm.prank(seller);
        market.addSupportedToken(address(usdcToken));
        
        // 市场owner添加USDC和DAI
        vm.startPrank(marketOwner);
        
        vm.expectEmit(true, false, false, false);
        emit NFTMarket.TokenAdded(address(usdcToken));
        market.addSupportedToken(address(usdcToken));
        
        vm.expectEmit(true, false, false, false);
        emit NFTMarket.TokenAdded(address(daiToken));
        market.addSupportedToken(address(daiToken));
        
        vm.stopPrank();
        
        // 验证代币被支持
        assertTrue(market.isTokenSupported(address(ttcToken))); // 默认支持
        assertTrue(market.isTokenSupported(address(usdcToken)));
        assertTrue(market.isTokenSupported(address(daiToken)));
    }

    // 测试用不同代币上架NFT
    function testListWithDifferentTokens() public {
        // 添加支持的代币
        vm.startPrank(marketOwner);
        market.addSupportedToken(address(usdcToken));
        market.addSupportedToken(address(daiToken));
        vm.stopPrank();
        
        // 卖家授权NFT给市场
        vm.startPrank(seller);
        nft.approve(address(market), TOKEN_ID_1);
        nft.approve(address(market), TOKEN_ID_2);
        nft.approve(address(market), TOKEN_ID_3);
        
        // 用不同代币上架NFT
        vm.expectEmit(true, true, false, true);
        emit NFTMarket.Listed(address(nft), TOKEN_ID_1, seller, TTC_PRICE, address(ttcToken));
        market.listWithToken(address(nft), TOKEN_ID_1, TTC_PRICE, address(ttcToken));
        
        vm.expectEmit(true, true, false, true);
        emit NFTMarket.Listed(address(nft), TOKEN_ID_2, seller, USDC_PRICE, address(usdcToken));
        market.listWithToken(address(nft), TOKEN_ID_2, USDC_PRICE, address(usdcToken));
        
        // 使用默认ttcoin上架
        vm.expectEmit(true, true, false, true);
        emit NFTMarket.Listed(address(nft), TOKEN_ID_3, seller, DAI_PRICE, address(ttcToken));
        market.list(address(nft), TOKEN_ID_3, DAI_PRICE);
        
        vm.stopPrank();
        
        // 验证上架信息
        (address seller1, uint256 price1, address token1) = market.getListing(address(nft), TOKEN_ID_1);
        assertEq(seller1, seller);
        assertEq(price1, TTC_PRICE);
        assertEq(token1, address(ttcToken));
        
        (address seller2, uint256 price2, address token2) = market.getListing(address(nft), TOKEN_ID_2);
        assertEq(seller2, seller);
        assertEq(price2, USDC_PRICE);
        assertEq(token2, address(usdcToken));
    }

    // 测试用指定代币购买NFT
    function testBuyWithSpecificToken() public {
        // 设置
        vm.startPrank(marketOwner);
        market.addSupportedToken(address(usdcToken));
        vm.stopPrank();
        
        // 上架NFT（要求USDC支付）
        vm.startPrank(seller);
        nft.approve(address(market), TOKEN_ID_1);
        market.listWithToken(address(nft), TOKEN_ID_1, USDC_PRICE, address(usdcToken));
        vm.stopPrank();
        
        // 买家用USDC购买
        uint256 sellerUsdcBefore = usdcToken.balanceOf(seller);
        uint256 buyerUsdcBefore = usdcToken.balanceOf(buyer1);
        
        vm.startPrank(buyer1);
        usdcToken.approve(address(market), USDC_PRICE);
        
        vm.expectEmit(true, true, false, true);
        emit NFTMarket.Bought(address(nft), TOKEN_ID_1, buyer1, USDC_PRICE, address(usdcToken));
        market.buyNFT(address(nft), TOKEN_ID_1);
        vm.stopPrank();
        
        // 验证交易结果
        assertEq(nft.ownerOf(TOKEN_ID_1), buyer1);
        assertEq(usdcToken.balanceOf(seller), sellerUsdcBefore + USDC_PRICE);
        assertEq(usdcToken.balanceOf(buyer1), buyerUsdcBefore - USDC_PRICE);
        
        // 验证上架记录已清除
        (address clearedSeller, uint256 clearedPrice, address clearedToken) = market.getListing(address(nft), TOKEN_ID_1);
        assertEq(clearedSeller, address(0));
        assertEq(clearedPrice, 0);
        assertEq(clearedToken, address(0));
    }

    // 测试callback购买（仅支持ttcoin）
    function testCallbackBuyOnlyTTCoin() public {
        // 上架NFT（要求TTC支付）
        vm.startPrank(seller);
        nft.approve(address(market), TOKEN_ID_1);
        market.listWithToken(address(nft), TOKEN_ID_1, TTC_PRICE, address(ttcToken));
        vm.stopPrank();
        
        // 用callback方式购买
        uint256 sellerTtcBefore = ttcToken.balanceOf(seller);
        uint256 buyerTtcBefore = ttcToken.balanceOf(buyer1);
        
        bytes memory data = abi.encode(address(nft), TOKEN_ID_1);
        
        vm.expectEmit(true, true, false, true);
        emit NFTMarket.Bought(address(nft), TOKEN_ID_1, buyer1, TTC_PRICE, address(ttcToken));
        
        vm.prank(buyer1);
        ttcToken.transferWithCallback(address(market), TTC_PRICE, data);
        
        // 验证交易结果
        assertEq(nft.ownerOf(TOKEN_ID_1), buyer1);
        assertEq(ttcToken.balanceOf(seller), sellerTtcBefore + TTC_PRICE);
        assertEq(ttcToken.balanceOf(buyer1), buyerTtcBefore - TTC_PRICE);
    }

    // 测试callback购买时支付代币不匹配的情况
    function testCallbackPaymentTokenMismatch() public {
        // 添加USDC支持
        vm.prank(marketOwner);
        market.addSupportedToken(address(usdcToken));
        
        // 上架NFT（要求USDC支付）
        vm.startPrank(seller);
        nft.approve(address(market), TOKEN_ID_1);
        market.listWithToken(address(nft), TOKEN_ID_1, USDC_PRICE, address(usdcToken));
        vm.stopPrank();
        
        // 尝试用TTC callback购买（应该失败）
        bytes memory data = abi.encode(address(nft), TOKEN_ID_1);
        
        vm.expectRevert("payment token mismatch");
        vm.prank(buyer1);
        ttcToken.transferWithCallback(address(market), TTC_PRICE, data);
    }

    // 测试移除支持的代币
    function testRemoveSupportedToken() public {
        // 添加USDC支持
        vm.prank(marketOwner);
        market.addSupportedToken(address(usdcToken));
        
        assertTrue(market.isTokenSupported(address(usdcToken)));
        
        // 移除USDC支持
        vm.expectEmit(true, false, false, false);
        emit NFTMarket.TokenRemoved(address(usdcToken));
        
        vm.prank(marketOwner);
        market.removeSupportedToken(address(usdcToken));
        
        assertFalse(market.isTokenSupported(address(usdcToken)));
        
        // 尝试用不支持的代币上架应该失败
        vm.startPrank(seller);
        nft.approve(address(market), TOKEN_ID_1);
        
        vm.expectRevert("payment token not supported");
        market.listWithToken(address(nft), TOKEN_ID_1, USDC_PRICE, address(usdcToken));
        vm.stopPrank();
    }

    // 测试混合代币交易场景
    function testMixedTokenTrading() public {
        // 添加所有代币支持
        vm.startPrank(marketOwner);
        market.addSupportedToken(address(usdcToken));
        market.addSupportedToken(address(daiToken));
        vm.stopPrank();
        
        // 上架多个NFT，使用不同代币
        vm.startPrank(seller);
        nft.approve(address(market), TOKEN_ID_1);
        nft.approve(address(market), TOKEN_ID_2);
        nft.approve(address(market), TOKEN_ID_3);
        
        market.listWithToken(address(nft), TOKEN_ID_1, TTC_PRICE, address(ttcToken));
        market.listWithToken(address(nft), TOKEN_ID_2, USDC_PRICE, address(usdcToken));  
        market.listWithToken(address(nft), TOKEN_ID_3, DAI_PRICE, address(daiToken));
        vm.stopPrank();
        
        // 不同买家用不同代币购买
        // buyer1用TTC买TOKEN_ID_1
        vm.startPrank(buyer1);
        ttcToken.approve(address(market), TTC_PRICE);
        market.buyNFT(address(nft), TOKEN_ID_1);
        vm.stopPrank();
        
        // buyer2用USDC买TOKEN_ID_2  
        vm.startPrank(buyer2);
        usdcToken.approve(address(market), USDC_PRICE);
        market.buyNFT(address(nft), TOKEN_ID_2);
        vm.stopPrank();
        
        // buyer1用DAI买TOKEN_ID_3
        vm.startPrank(buyer1);
        daiToken.approve(address(market), DAI_PRICE);
        market.buyNFT(address(nft), TOKEN_ID_3);
        vm.stopPrank();
        
        // 验证所有交易成功
        assertEq(nft.ownerOf(TOKEN_ID_1), buyer1);
        assertEq(nft.ownerOf(TOKEN_ID_2), buyer2);
        assertEq(nft.ownerOf(TOKEN_ID_3), buyer1);
    }

    // 新增：测试上架成功与失败场景（断言错误信息和上架事件）
    function testListingSuccessAndFailures() public {
        // 成功上架（使用默认ttcoin）
        vm.startPrank(seller);
        nft.approve(address(market), TOKEN_ID_1);
        vm.expectEmit(true, true, false, true);
        emit NFTMarket.Listed(address(nft), TOKEN_ID_1, seller, TTC_PRICE, address(ttcToken));
        market.list(address(nft), TOKEN_ID_1, TTC_PRICE);
        vm.stopPrank();

        // 价格为0应该失败
        vm.startPrank(seller);
        nft.approve(address(market), TOKEN_ID_2);
        vm.expectRevert(bytes("price zero"));
        market.list(address(nft), TOKEN_ID_2, 0);
        vm.stopPrank();

        // 使用不被支持的代币上架应该失败（USDC尚未被添加）
        vm.startPrank(seller);
        nft.approve(address(market), TOKEN_ID_3);
        vm.expectRevert(bytes("payment token not supported"));
        market.listWithToken(address(nft), TOKEN_ID_3, USDC_PRICE, address(usdcToken));
        vm.stopPrank();

        // 非NFT持有者尝试上架应该失败
        vm.prank(buyer1);
        vm.expectRevert(bytes("not owner"));
        market.list(address(nft), TOKEN_ID_1, TTC_PRICE);
    }

    // 新增：测试购买成功、自己购买自己的NFT、重复购买、以及支付过多/过少场景
    function testBuyEdgeCases() public {
        // 添加USDC支持用于部分测试
        vm.startPrank(marketOwner);
        market.addSupportedToken(address(usdcToken));
        vm.stopPrank();

        // 卖家上架一个要求USDC支付的NFT
        vm.startPrank(seller);
        nft.approve(address(market), TOKEN_ID_1);
        market.listWithToken(address(nft), TOKEN_ID_1, USDC_PRICE, address(usdcToken));
        vm.stopPrank();

        // 卖家尝试自己购买（卖家没有USDC余额，应当因为余额不足或Allowance问题失败）
        vm.prank(seller);
        vm.expectRevert(bytes("Insufficient balance"));
        market.buyNFT(address(nft), TOKEN_ID_1);

        // 买家正常购买成功
        vm.startPrank(buyer1);
        usdcToken.approve(address(market), USDC_PRICE);
        vm.expectEmit(true, true, false, true);
        emit NFTMarket.Bought(address(nft), TOKEN_ID_1, buyer1, USDC_PRICE, address(usdcToken));
        market.buyNFT(address(nft), TOKEN_ID_1);
        vm.stopPrank();

        // 重复购买应该失败（已经被买走）
        vm.startPrank(buyer2);
        usdcToken.approve(address(market), USDC_PRICE);
        vm.expectRevert(bytes("not listed"));
        market.buyNFT(address(nft), TOKEN_ID_1);
        vm.stopPrank();

        // 使用ttcoin的callback购买：上架要求TTC
        vm.startPrank(seller);
        nft.approve(address(market), TOKEN_ID_2);
        market.listWithToken(address(nft), TOKEN_ID_2, TTC_PRICE, address(ttcToken));
        vm.stopPrank();

        bytes memory data = abi.encode(address(nft), TOKEN_ID_2);

        // 用callback方式支付但金额不足 -> 失败
        vm.prank(buyer1);
        vm.expectRevert(bytes("price not enough"));
        ttcToken.transferWithCallback(address(market), TTC_PRICE - 1, data);

        // 用callback方式支付并超过价格 -> 成功（合约只会转移price给卖家）
        uint256 sellerTtcBefore = ttcToken.balanceOf(seller);
        vm.prank(buyer1);
        vm.expectEmit(true, true, false, true);
        emit NFTMarket.Bought(address(nft), TOKEN_ID_2, buyer1, TTC_PRICE, address(ttcToken));
        ttcToken.transferWithCallback(address(market), TTC_PRICE + 1000, data);
        assertEq(ttcToken.balanceOf(seller), sellerTtcBefore + TTC_PRICE);

        // 测试当买家approve不足时，ERC20的transferFrom会报Allowance错误（buyNFT场景）
        // 上架一个新的USDC支付NFT
        vm.startPrank(seller);
        nft.approve(address(market), TOKEN_ID_3);
        market.listWithToken(address(nft), TOKEN_ID_3, USDC_PRICE, address(usdcToken));
        vm.stopPrank();

        // buyer2只approve少量，应该在transferFrom阶段失败
        vm.startPrank(buyer2);
        usdcToken.approve(address(market), USDC_PRICE - 1);
        vm.expectRevert(bytes("Allowance exceeded"));
        market.buyNFT(address(nft), TOKEN_ID_3);
        vm.stopPrank();
    }
}