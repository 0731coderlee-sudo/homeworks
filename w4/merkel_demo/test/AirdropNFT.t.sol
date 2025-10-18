// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/AirdropNFT.sol";

contract AirdropNFTTest is Test {
    AirdropNFT public nft;
    address public owner;
    address public user1;
    address public user2;

    string constant BASE_URI = "ipfs://QmTest/";

    function setUp() public {
        owner = address(this);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        nft = new AirdropNFT("Airdrop NFT", "ANFT");
    }

    function test_InitialState() public view {
        assertEq(nft.name(), "Airdrop NFT");
        assertEq(nft.symbol(), "ANFT");
        assertEq(nft.nextTokenId(), 0);
    }

    function test_Mint() public {
        string memory uri = string.concat(BASE_URI, "1");

        uint256 tokenId = nft.mint(user1, uri);

        assertEq(tokenId, 0);
        assertEq(nft.ownerOf(tokenId), user1);
        assertEq(nft.tokenURI(tokenId), uri);
        assertEq(nft.nextTokenId(), 1);
    }

    function test_MintMultiple() public {
        string memory uri1 = string.concat(BASE_URI, "1");
        string memory uri2 = string.concat(BASE_URI, "2");

        uint256 tokenId1 = nft.mint(user1, uri1);
        uint256 tokenId2 = nft.mint(user2, uri2);

        assertEq(tokenId1, 0);
        assertEq(tokenId2, 1);
        assertEq(nft.ownerOf(tokenId1), user1);
        assertEq(nft.ownerOf(tokenId2), user2);
        assertEq(nft.nextTokenId(), 2);
    }

    function test_MintOnlyOwner() public {
        string memory uri = string.concat(BASE_URI, "1");

        vm.prank(user1);
        vm.expectRevert();
        nft.mint(user2, uri);
    }

    function test_Transfer() public {
        string memory uri = string.concat(BASE_URI, "1");
        uint256 tokenId = nft.mint(user1, uri);

        vm.prank(user1);
        nft.transferFrom(user1, user2, tokenId);

        assertEq(nft.ownerOf(tokenId), user2);
    }

    function test_SupportsInterface() public view {
        // ERC721 interface
        assertTrue(nft.supportsInterface(0x80ac58cd));
        // ERC721Metadata interface
        assertTrue(nft.supportsInterface(0x5b5e139f));
    }
}
