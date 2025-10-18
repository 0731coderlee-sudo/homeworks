// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/AirdropToken.sol";

contract AirdropTokenTest is Test {
    AirdropToken public token;
    address public owner;
    address public user1;
    address public user2;

    uint256 constant INITIAL_SUPPLY = 1_000_000 * 10**18;

    function setUp() public {
        owner = address(this);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        token = new AirdropToken("Airdrop Token", "ADT", INITIAL_SUPPLY);
    }

    function test_InitialState() public view {
        assertEq(token.name(), "Airdrop Token");
        assertEq(token.symbol(), "ADT");
        assertEq(token.totalSupply(), INITIAL_SUPPLY);
        assertEq(token.balanceOf(owner), INITIAL_SUPPLY);
    }

    function test_Mint() public {
        uint256 mintAmount = 1000 * 10**18;

        token.mint(user1, mintAmount);

        assertEq(token.balanceOf(user1), mintAmount);
        assertEq(token.totalSupply(), INITIAL_SUPPLY + mintAmount);
    }

    function test_MintOnlyOwner() public {
        uint256 mintAmount = 1000 * 10**18;

        vm.prank(user1);
        vm.expectRevert();
        token.mint(user2, mintAmount);
    }

    function test_Transfer() public {
        uint256 transferAmount = 100 * 10**18;

        token.transfer(user1, transferAmount);

        assertEq(token.balanceOf(user1), transferAmount);
        assertEq(token.balanceOf(owner), INITIAL_SUPPLY - transferAmount);
    }
}
