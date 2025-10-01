// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/BaseERC721.sol";

contract FlexibleMintTest is Test {
    BaseERC721 public nft;
    address public owner;
    address public user1;
    address public user2;

    function setUp() public {
        owner = makeAddr("owner");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        
        vm.prank(owner);
        nft = new BaseERC721("FlexibleNFT", "FNFT", "https://api.example.com/");
    }

    // 测试传统mint方式（使用baseURI + tokenId）
    function testTraditionalMint() public {
        vm.prank(owner);
        nft.mint(user1, 1);
        
        assertEq(nft.ownerOf(1), user1);
        assertEq(nft.tokenURI(1), "https://api.example.com/1");
        assertEq(nft.getCustomTokenURI(1), ""); // 没有自定义URI
    }

    // 测试使用自定义URI的mint
    function testMintWithCustomURI() public {
        string memory customURI = "ipfs://QmCustomHash1/metadata.json";
        
        vm.prank(owner);
        nft.mintWithURI(user1, 1, customURI);
        
        assertEq(nft.ownerOf(1), user1);
        assertEq(nft.tokenURI(1), customURI);
        assertEq(nft.getCustomTokenURI(1), customURI);
    }

    // 测试批量mint with URIs
    function testBatchMintWithURIs() public {
        uint256[] memory tokenIds = new uint256[](3);
        tokenIds[0] = 10;
        tokenIds[1] = 20;
        tokenIds[2] = 30;
        
        string[] memory customURIs = new string[](3);
        customURIs[0] = "ipfs://QmHash1/metadata.json";
        customURIs[1] = "ipfs://QmHash2/metadata.json";
        customURIs[2] = "ipfs://QmHash3/metadata.json";
        
        vm.prank(owner);
        nft.batchMintWithURIs(user1, tokenIds, customURIs);
        
        assertEq(nft.balanceOf(user1), 3);
        assertEq(nft.tokenURI(10), customURIs[0]);
        assertEq(nft.tokenURI(20), customURIs[1]);
        assertEq(nft.tokenURI(30), customURIs[2]);
    }

    // 测试自动递增mint
    function testAutoMintWithURI() public {
        string memory uri1 = "ipfs://QmAutoHash1/metadata.json";
        string memory uri2 = "ipfs://QmAutoHash2/metadata.json";
        
        vm.startPrank(owner);
        
        uint256 tokenId1 = nft.autoMintWithURI(user1, uri1);
        uint256 tokenId2 = nft.autoMintWithURI(user2, uri2);
        
        vm.stopPrank();
        
        assertEq(tokenId1, 1);
        assertEq(tokenId2, 2);
        assertEq(nft.ownerOf(tokenId1), user1);
        assertEq(nft.ownerOf(tokenId2), user2);
        assertEq(nft.tokenURI(tokenId1), uri1);
        assertEq(nft.tokenURI(tokenId2), uri2);
    }

    // 测试设置现有token的URI
    function testSetTokenURI() public {
        // 先用传统方式mint
        vm.prank(owner);
        nft.mint(user1, 1);
        
        assertEq(nft.tokenURI(1), "https://api.example.com/1");
        
        // 设置自定义URI
        string memory newURI = "ipfs://QmNewHash/metadata.json";
        vm.prank(owner);
        nft.setTokenURI(1, newURI);
        
        assertEq(nft.tokenURI(1), newURI);
    }

    // 测试混合使用场景
    function testMixedUsageScenario() public {
        vm.startPrank(owner);
        
        // 1. 传统mint（使用baseURI）
        nft.mint(user1, 100);
        
        // 2. 自定义URI mint
        nft.mintWithURI(user1, 200, "ipfs://QmSpecial/metadata.json");
        
        // 3. 自动递增mint
        uint256 autoId = nft.autoMintWithURI(user2, "ipfs://QmAuto/metadata.json");
        
        vm.stopPrank();
        
        assertEq(nft.tokenURI(100), "https://api.example.com/100"); // 使用baseURI
        assertEq(nft.tokenURI(200), "ipfs://QmSpecial/metadata.json"); // 使用自定义URI
        assertEq(nft.tokenURI(autoId), "ipfs://QmAuto/metadata.json"); // 自动ID，自定义URI
    }

    // 测试burn时清理自定义URI
    function testBurnClearsCustomURI() public {
        string memory customURI = "ipfs://QmToBurn/metadata.json";
        
        vm.prank(owner);
        nft.mintWithURI(user1, 1, customURI);
        
        assertEq(nft.getCustomTokenURI(1), customURI);
        
        // burn token
        vm.prank(user1);
        nft.burn(1);
        
        // 验证token不存在
        vm.expectRevert("ERC721: owner query for nonexistent token");
        nft.ownerOf(1);
        
        // 自定义URI应该被清理（通过重新mint同一个ID验证）
        vm.prank(owner);
        nft.mint(user2, 1);
        assertEq(nft.tokenURI(1), "https://api.example.com/1"); // 应该使用baseURI，不是之前的自定义URI
    }

    // 测试权限控制
    function testOnlyOwnerCanMintWithURI() public {
        vm.expectRevert("BaseERC721: caller is not the owner");
        vm.prank(user1);
        nft.mintWithURI(user1, 1, "ipfs://QmTest/metadata.json");
        
        vm.expectRevert("BaseERC721: caller is not the owner");
        vm.prank(user1);
        nft.setTokenURI(1, "ipfs://QmTest/metadata.json");
    }

    // 测试错误情况
    function testErrorCases() public {
        vm.startPrank(owner);
        
        // 空URI应该失败
        vm.expectRevert("ERC721: URI cannot be empty");
        nft.mintWithURI(user1, 1, "");
        
        // 数组长度不匹配应该失败
        uint256[] memory tokenIds = new uint256[](2);
        string[] memory uris = new string[](1);
        tokenIds[0] = 1;
        tokenIds[1] = 2;
        uris[0] = "ipfs://QmTest/metadata.json";
        
        vm.expectRevert("ERC721: arrays length mismatch");
        nft.batchMintWithURIs(user1, tokenIds, uris);
        
        // 为不存在的token设置URI应该失败
        vm.expectRevert("ERC721: URI set for nonexistent token");
        nft.setTokenURI(999, "ipfs://QmTest/metadata.json");
        
        vm.stopPrank();
    }
}