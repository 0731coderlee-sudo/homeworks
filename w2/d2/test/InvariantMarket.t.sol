// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/StdInvariant.sol";
import "forge-std/Test.sol";
import "../src/BaseERC721.sol";
import "../src/ttcoin.sol";
import "../src/NFTMarket.sol";

contract InvariantMarketTest is StdInvariant, Test {
    ttcoin public ttcToken;
    NFTMarket public market;
    BaseERC721 public nft;

    address public marketOwner;
    address public nftOwner;
    address public seller;

    function setUp() public {
        marketOwner = makeAddr("marketOwner");
        nftOwner = makeAddr("nftOwner");
        seller = makeAddr("seller");

        vm.prank(seller);
        ttcToken = new ttcoin(1_000_000_000, "TestCoin", "TTC");

        vm.prank(nftOwner);
        nft = new BaseERC721("InvNFT", "INV", "https://example.com/");

        vm.prank(marketOwner);
        market = new NFTMarket(ttcToken);

    // register the target contracts for invariant fuzzing (market and token)
    targetContract(address(market));
    targetContract(address(ttcToken));
    targetContract(address(nft));

    // prepare a listed NFT so the fuzzer can exercise purchase paths (including callback)
    uint256 tokenId = 1;
    vm.prank(nftOwner);
    nft.mint(seller, tokenId);
    vm.startPrank(seller);
    nft.approve(address(market), tokenId);
    // list with a nominal price so callbacks can be executed by the fuzzer
    market.listWithToken(address(nft), tokenId, 100 * 10**18, address(ttcToken));
    vm.stopPrank();
    }

    // Invariant: market should never hold TTC tokens (for correct buy/list flows)
    function invariant_market_holds_no_ttc() public view {
        assert(ttcToken.balanceOf(address(market)) == 0);
    }

    // Deterministic test: seller uses transferWithCallback to buy their own NFT with excess
    // This checks whether excess tokens remain in the market contract after the callback.
    function test_seller_callback_overpay_leaves_excess() public {
        uint256 tokenId = 12345;
        uint256 price = 100 * 10**18;
        uint256 excess = 25 * 10**18;

        // mint NFT to seller and list
        vm.prank(nftOwner);
        nft.mint(seller, tokenId);

        vm.startPrank(seller);
        nft.approve(address(market), tokenId);
        market.listWithToken(address(nft), tokenId, price, address(ttcToken));
        vm.stopPrank();

        // seller transfers price + excess to market via callback
        bytes memory data = abi.encode(address(nft), tokenId);
        vm.prank(seller);
        ttcToken.transferWithCallback(address(market), price + excess, data);

        // Current NFTMarket implementation sends 'price' to seller but does not refund excess.
        // So the excess should remain in the market contract's balance.
        assertEq(ttcToken.balanceOf(address(market)), excess);

        // Listing must have been cleared and NFT transferred to 'seller' (self-buy)
        (address s, uint256 p, address t) = market.getListing(address(nft), tokenId);
        assertEq(s, address(0));
        assertEq(p, 0);
        assertEq(t, address(0));
        assertEq(nft.ownerOf(tokenId), seller);
    }
}
