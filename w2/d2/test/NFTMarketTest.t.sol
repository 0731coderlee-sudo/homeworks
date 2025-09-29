// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/ttcoin.sol";
import "../src/BaseERC721.sol";
import "../src/NFTMarket.sol";

contract NFTMarketTest is Test {
    ttcoin token;
    BaseERC721 nft;
    NFTMarket market;
    address seller = address(0x1);
    address buyer = address(0x2);

    function setUp() public {
        token = new ttcoin(10000, "TT", "TT");
        nft = new BaseERC721("NFT", "NFT", "ipfs://cid/");
        market = new NFTMarket(token);

        // 给seller和buyer分配token
        token.transfer(seller, 1000 ether);
        token.transfer(buyer, 1000 ether);

        // seller mint NFT
        vm.prank(seller);
        nft.mint(seller, 1);

        // seller approve NFTMarket操作NFT
        vm.prank(seller);
        nft.approve(address(market), 1);
    }

    function testListAndBuyNFT() public {
        // seller上架NFT
        vm.prank(seller);
        market.list(address(nft), 1, 100 ether);

        // buyer approve token
        vm.prank(buyer);
        token.approve(address(market), 100 ether);

        // buyer购买NFT
        vm.prank(buyer);
        market.buyNFT(address(nft), 1);

        // 检查NFT归属
        assertEq(nft.ownerOf(1), buyer);
        // 检查seller收到token
        assertEq(token.balanceOf(seller), 1100 ether);
        // 检查buyer扣除token
        assertEq(token.balanceOf(buyer), 900 ether);
    }

    function testBuyNFTWithCallback() public {
        // seller上架NFT
        vm.prank(seller);
        market.list(address(nft), 1, 100 ether);

        // buyer用transferWithCallback购买
        bytes memory data = abi.encode(address(nft), 1);
        vm.prank(buyer);
        token.approve(address(market), 100 ether); // 先approve
        vm.prank(buyer);
        token.transferWithCallback(address(market), 100 ether, data);

        // 检查NFT归属
        assertEq(nft.ownerOf(1), buyer);
        // 检查seller收到token
        assertEq(token.balanceOf(seller), 1100 ether);
        // 检查buyer扣除token
        assertEq(token.balanceOf(buyer), 900 ether);
    }
}