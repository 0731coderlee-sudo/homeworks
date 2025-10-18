// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/MerkleAirdrop.sol";
import "../src/AirdropToken.sol";

contract MerkleAirdropTest is Test {
    MerkleAirdrop public airdrop;
    AirdropToken public token;

    address public owner;
    address public user1;
    address public user2;
    address public user3;

    uint256 constant TOTAL_SUPPLY = 10_000_000 * 10**18;

    // Merkle tree for testing
    // Tree structure:
    //         root
    //        /    \
    //      h1      h2
    //     /  \    /  \
    //   l1   l2  l3  l4
    //
    // l1 = hash(user1, 1000 ether)
    // l2 = hash(user2, 2000 ether)
    // l3 = hash(user3, 3000 ether)
    // l4 = hash(address(0), 0) - dummy leaf for tree balance

    bytes32 public merkleRoot;

    // Amounts for each user
    uint256 constant AMOUNT_USER1 = 1000 ether;
    uint256 constant AMOUNT_USER2 = 2000 ether;
    uint256 constant AMOUNT_USER3 = 3000 ether;

    function setUp() public {
        owner = address(this);
        user1 = address(0x1111);
        user2 = address(0x2222);
        user3 = address(0x3333);

        // Deploy token
        token = new AirdropToken("Airdrop Token", "ADT", TOTAL_SUPPLY);

        // Calculate merkle tree manually
        bytes32 leaf1 = keccak256(bytes.concat(keccak256(abi.encode(user1, AMOUNT_USER1))));
        bytes32 leaf2 = keccak256(bytes.concat(keccak256(abi.encode(user2, AMOUNT_USER2))));
        bytes32 leaf3 = keccak256(bytes.concat(keccak256(abi.encode(user3, AMOUNT_USER3))));
        bytes32 leaf4 = keccak256(bytes.concat(keccak256(abi.encode(address(0), 0))));

        // Build tree bottom-up
        bytes32 h1 = leaf1 < leaf2 ?
            keccak256(abi.encodePacked(leaf1, leaf2)) :
            keccak256(abi.encodePacked(leaf2, leaf1));

        bytes32 h2 = leaf3 < leaf4 ?
            keccak256(abi.encodePacked(leaf3, leaf4)) :
            keccak256(abi.encodePacked(leaf4, leaf3));

        merkleRoot = h1 < h2 ?
            keccak256(abi.encodePacked(h1, h2)) :
            keccak256(abi.encodePacked(h2, h1));

        // Deploy airdrop contract
        airdrop = new MerkleAirdrop(address(token), merkleRoot);

        // Transfer tokens to airdrop contract
        token.transfer(address(airdrop), 10000 ether);
    }

    function test_InitialState() public view {
        assertEq(address(airdrop.token()), address(token));
        assertEq(airdrop.merkleRoot(), merkleRoot);
        assertEq(token.balanceOf(address(airdrop)), 10000 ether);
    }

    function test_ClaimUser1() public {
        // Generate proof for user1
        bytes32 leaf1 = keccak256(bytes.concat(keccak256(abi.encode(user1, AMOUNT_USER1))));
        bytes32 leaf2 = keccak256(bytes.concat(keccak256(abi.encode(user2, AMOUNT_USER2))));
        bytes32 leaf3 = keccak256(bytes.concat(keccak256(abi.encode(user3, AMOUNT_USER3))));
        bytes32 leaf4 = keccak256(bytes.concat(keccak256(abi.encode(address(0), 0))));

        bytes32 h1 = leaf1 < leaf2 ?
            keccak256(abi.encodePacked(leaf1, leaf2)) :
            keccak256(abi.encodePacked(leaf2, leaf1));

        bytes32 h2 = leaf3 < leaf4 ?
            keccak256(abi.encodePacked(leaf3, leaf4)) :
            keccak256(abi.encodePacked(leaf4, leaf3));

        // Proof for user1: [leaf2, h2]
        bytes32[] memory proof = new bytes32[](2);
        proof[0] = leaf2;
        proof[1] = h2;

        uint256 balanceBefore = token.balanceOf(user1);

        vm.prank(user1);
        vm.expectEmit(true, false, false, true);
        emit MerkleAirdrop.Claimed(user1, AMOUNT_USER1);
        airdrop.claim(AMOUNT_USER1, proof);

        assertEq(token.balanceOf(user1), balanceBefore + AMOUNT_USER1);
        assertTrue(airdrop.hasClaimed(user1));
        assertTrue(airdrop.isClaimed(user1));
    }

    function test_ClaimUser2() public {
        // Generate proof for user2
        bytes32 leaf1 = keccak256(bytes.concat(keccak256(abi.encode(user1, AMOUNT_USER1))));
        bytes32 leaf2 = keccak256(bytes.concat(keccak256(abi.encode(user2, AMOUNT_USER2))));
        bytes32 leaf3 = keccak256(bytes.concat(keccak256(abi.encode(user3, AMOUNT_USER3))));
        bytes32 leaf4 = keccak256(bytes.concat(keccak256(abi.encode(address(0), 0))));

        bytes32 h1 = leaf1 < leaf2 ?
            keccak256(abi.encodePacked(leaf1, leaf2)) :
            keccak256(abi.encodePacked(leaf2, leaf1));

        bytes32 h2 = leaf3 < leaf4 ?
            keccak256(abi.encodePacked(leaf3, leaf4)) :
            keccak256(abi.encodePacked(leaf4, leaf3));

        // Proof for user2: [leaf1, h2]
        bytes32[] memory proof = new bytes32[](2);
        proof[0] = leaf1;
        proof[1] = h2;

        uint256 balanceBefore = token.balanceOf(user2);

        vm.prank(user2);
        airdrop.claim(AMOUNT_USER2, proof);

        assertEq(token.balanceOf(user2), balanceBefore + AMOUNT_USER2);
        assertTrue(airdrop.hasClaimed(user2));
    }

    function test_RevertDoubleClaim() public {
        // Generate proof for user1
        bytes32 leaf1 = keccak256(bytes.concat(keccak256(abi.encode(user1, AMOUNT_USER1))));
        bytes32 leaf2 = keccak256(bytes.concat(keccak256(abi.encode(user2, AMOUNT_USER2))));
        bytes32 leaf3 = keccak256(bytes.concat(keccak256(abi.encode(user3, AMOUNT_USER3))));
        bytes32 leaf4 = keccak256(bytes.concat(keccak256(abi.encode(address(0), 0))));

        bytes32 h1 = leaf1 < leaf2 ?
            keccak256(abi.encodePacked(leaf1, leaf2)) :
            keccak256(abi.encodePacked(leaf2, leaf1));

        bytes32 h2 = leaf3 < leaf4 ?
            keccak256(abi.encodePacked(leaf3, leaf4)) :
            keccak256(abi.encodePacked(leaf4, leaf3));

        bytes32[] memory proof = new bytes32[](2);
        proof[0] = leaf2;
        proof[1] = h2;

        // First claim should succeed
        vm.prank(user1);
        airdrop.claim(AMOUNT_USER1, proof);

        // Second claim should fail
        vm.prank(user1);
        vm.expectRevert(MerkleAirdrop.AlreadyClaimed.selector);
        airdrop.claim(AMOUNT_USER1, proof);
    }

    function test_RevertInvalidProof() public {
        bytes32[] memory invalidProof = new bytes32[](2);
        invalidProof[0] = bytes32(uint256(1));
        invalidProof[1] = bytes32(uint256(2));

        vm.prank(user1);
        vm.expectRevert(MerkleAirdrop.InvalidProof.selector);
        airdrop.claim(AMOUNT_USER1, invalidProof);
    }

    function test_RevertInvalidAmount() public {
        // Generate valid proof but wrong amount
        bytes32 leaf1 = keccak256(bytes.concat(keccak256(abi.encode(user1, AMOUNT_USER1))));
        bytes32 leaf2 = keccak256(bytes.concat(keccak256(abi.encode(user2, AMOUNT_USER2))));
        bytes32 leaf3 = keccak256(bytes.concat(keccak256(abi.encode(user3, AMOUNT_USER3))));
        bytes32 leaf4 = keccak256(bytes.concat(keccak256(abi.encode(address(0), 0))));

        bytes32 h1 = leaf1 < leaf2 ?
            keccak256(abi.encodePacked(leaf1, leaf2)) :
            keccak256(abi.encodePacked(leaf2, leaf1));

        bytes32 h2 = leaf3 < leaf4 ?
            keccak256(abi.encodePacked(leaf3, leaf4)) :
            keccak256(abi.encodePacked(leaf4, leaf3));

        bytes32[] memory proof = new bytes32[](2);
        proof[0] = leaf2;
        proof[1] = h2;

        // Try to claim wrong amount
        vm.prank(user1);
        vm.expectRevert(MerkleAirdrop.InvalidProof.selector);
        airdrop.claim(AMOUNT_USER1 + 1 ether, proof);
    }

    function test_WithdrawRemaining() public {
        uint256 remainingBalance = token.balanceOf(address(airdrop));
        uint256 ownerBalanceBefore = token.balanceOf(owner);

        airdrop.withdrawRemaining(owner);

        assertEq(token.balanceOf(address(airdrop)), 0);
        assertEq(token.balanceOf(owner), ownerBalanceBefore + remainingBalance);
    }

    function test_WithdrawRemainingOnlyOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        airdrop.withdrawRemaining(user1);
    }
}
