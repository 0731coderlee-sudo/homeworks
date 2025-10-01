// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/BaseERC721.sol";
import "../src/ttcoin.sol";
import "../src/NFTMarket.sol";

contract FuzzMarketTest is Test {
    BaseERC721 public nft;
    ttcoin public ttcToken;
    NFTMarket public market;

    address public marketOwner;
    address public nftOwner;
    address public seller;

    function setUp() public {
        marketOwner = makeAddr("marketOwner");
        nftOwner = makeAddr("nftOwner");
        seller = makeAddr("seller");

        // deploy ttcoin with seller as initial holder
        vm.prank(seller);
        ttcToken = new ttcoin(1_000_000_000, "TestCoin", "TTC");

        // deploy NFT contract
        vm.prank(nftOwner);
        nft = new BaseERC721("FuzzNFT", "FZ", "https://example.com/");

        // deploy market with ttcoin as callback token
        vm.prank(marketOwner);
        market = new NFTMarket(ttcToken);
    }

    // Helper to bound price into [0.01, 10000] * 1e18
    function _boundedPrice(uint256 v) internal pure returns (uint256) {
        uint256 min = 10**16; // 0.01 * 1e18
        uint256 max = 10000 * 10**18;
        uint256 range = max - min;
        return min + (v % (range + 1));
    }

    // Fuzz: random price and random buyer (approve+buy path, exact payment)
    function testFuzz_ListAndBuy_Approve(uint256 seed, address buyer) public {
        // filter bad addresses
        vm.assume(buyer != address(0));
        vm.assume(buyer != seller);
        vm.assume(buyer != nftOwner);
        vm.assume(buyer != marketOwner);

        uint256 price = _boundedPrice(seed);

        // Mint tokenId derived from seed
        uint256 tokenId = (uint256(keccak256(abi.encodePacked(seed))) % 1000) + 1;

        // mint to seller
        vm.prank(nftOwner);
        nft.mint(seller, tokenId);

        // seller approve and list
        vm.startPrank(seller);
        nft.approve(address(market), tokenId);
        market.listWithToken(address(nft), tokenId, price, address(ttcToken));
        vm.stopPrank();

        // transfer exact price to buyer from seller
        vm.prank(seller);
        ttcToken.transfer(buyer, price);

        // buyer approve and buy
        vm.prank(buyer);
        ttcToken.approve(address(market), price);
        vm.prank(buyer);
        market.buyNFT(address(nft), tokenId);

        // After exact-price buy, market should not hold any ttcoin
        assertEq(ttcToken.balanceOf(address(market)), 0);
        // ownership moved
        assertEq(nft.ownerOf(tokenId), buyer);
    }

    // Fuzz: random price and random buyer (callback path, exact payment)
    function testFuzz_ListAndBuy_Callback(uint256 seed, address buyer) public {
        vm.assume(buyer != address(0));
        vm.assume(buyer != seller);
        vm.assume(buyer != nftOwner);
        vm.assume(buyer != marketOwner);

        uint256 price = _boundedPrice(seed);
        uint256 tokenId = (uint256(keccak256(abi.encodePacked(seed, buyer))) % 1000) + 1001;

        // mint to seller
        vm.prank(nftOwner);
        nft.mint(seller, tokenId);

        // seller approve and list (use ttcoin)
        vm.startPrank(seller);
        nft.approve(address(market), tokenId);
        market.listWithToken(address(nft), tokenId, price, address(ttcToken));
        vm.stopPrank();

        // transfer tokens from seller to buyer so buyer has balance
        vm.prank(seller);
        ttcToken.transfer(buyer, price);

        // buyer uses transferWithCallback to pay exact price
        bytes memory data = abi.encode(address(nft), tokenId);
        vm.prank(buyer);
        ttcToken.transferWithCallback(address(market), price, data);

        // After exact-price callback, market should not hold ttcoin
        assertEq(ttcToken.balanceOf(address(market)), 0);
        assertEq(nft.ownerOf(tokenId), buyer);
    }

    // Optional invariant test: run a sequence of random list/buy events and assert market balance stays zero
    function testSequence_Invariant_NoMarketHoldings(uint256 seed) public {
        // create a few tokens and buyers deterministically from seed
        address[] memory buyers = new address[](4);
        for (uint256 i = 0; i < buyers.length; i++) {
            buyers[i] = vm.addr(uint256(keccak256(abi.encodePacked(seed, i))));
            // transfer ample ttcoin to each buyer from seller to cover random prices (max 10000 * 1e18)
            vm.prank(seller);
            ttcToken.transfer(buyers[i], 1000000 * 10**18);
        }

        // do 8 random operations
        for (uint256 i = 0; i < 8; i++) {
            uint256 price = _boundedPrice(uint256(keccak256(abi.encodePacked(seed, i))));
            uint256 tokenId = i + 2000;

            // mint
            vm.prank(nftOwner);
            nft.mint(seller, tokenId);

            // seller list
            vm.startPrank(seller);
            nft.approve(address(market), tokenId);
            market.listWithToken(address(nft), tokenId, price, address(ttcToken));
            vm.stopPrank();

            // pick buyer
            address b = buyers[i % buyers.length];
            // buyer approve & buy
            vm.prank(b);
            ttcToken.approve(address(market), price);
            vm.prank(b);
            market.buyNFT(address(nft), tokenId);

            // invariant: market has zero ttcoin
            assertEq(ttcToken.balanceOf(address(market)), 0);
        }
    }
}
