// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../ttcoin.sol";
import "../tokenbank.sol";

contract TokenBankTest is Test {
    ttcoin public token;
    TokenBank public bank;
    address public user = address(0x1);
    address public user2 = address(0x2);
    uint256 public constant INITIAL_SUPPLY = 1000000;
    uint256 public constant DECIMALS = 18;

    function setUp() public {
        token = new ttcoin(INITIAL_SUPPLY, "TestToken", "TT");
        bank = new TokenBank(token);
        token.transfer(user, 1000 * 10**DECIMALS);
        token.transfer(user2, 500 * 10**DECIMALS);
    }

    function testDepositWithdraw() public {
        vm.prank(user);
        token.approve(address(bank), 500 * 10**DECIMALS);
        vm.prank(user);
        bank.deposit(500 * 10**DECIMALS);
        assertEq(bank.balanceOf(user), 500 * 10**DECIMALS);

        // 提现部分余额
        vm.prank(user);
        bank.withdraw(200 * 10**DECIMALS);
        assertEq(bank.balanceOf(user), 300 * 10**DECIMALS);

        // 全部提现
        vm.prank(user);
        bank.withdraw(300 * 10**DECIMALS);
        assertEq(bank.balanceOf(user), 0);

        // 余额不足提现
        vm.prank(user);
        vm.expectRevert("insufficient balance");
        bank.withdraw(1);
    }

    function testDepositZeroAmount() public {
        vm.prank(user);
        token.approve(address(bank), 0);
        vm.prank(user);
        vm.expectRevert("amount zero");
        bank.deposit(0);
    }

    function testWithdrawZeroAmount() public {
        vm.prank(user);
        vm.expectRevert("amount zero");
        bank.withdraw(0);
    }

    function testApproveAndCallDeposit() public {
        vm.prank(user);
        token.approveAndCall(address(bank), 400 * 10**DECIMALS, "");
        assertEq(bank.balanceOf(user), 400 * 10**DECIMALS);
    }

    function testTransferWithCallbackDeposit() public {
        vm.prank(user);
        token.transferWithCallback(address(bank), 100 * 10**DECIMALS, "");
        assertEq(bank.balanceOf(user), 100 * 10**DECIMALS);
    }

    function testMultipleUsersDepositWithdraw() public {
        // user1 存款
        vm.prank(user);
        token.approve(address(bank), 300 * 10**DECIMALS);
        vm.prank(user);
        bank.deposit(300 * 10**DECIMALS);

        // user2 存款
        vm.prank(user2);
        token.approve(address(bank), 200 * 10**DECIMALS);
        vm.prank(user2);
        bank.deposit(200 * 10**DECIMALS);

        assertEq(bank.balanceOf(user), 300 * 10**DECIMALS);
        assertEq(bank.balanceOf(user2), 200 * 10**DECIMALS);

        // user2 提现
        vm.prank(user2);
        bank.withdraw(50 * 10**DECIMALS);
        assertEq(bank.balanceOf(user2), 150 * 10**DECIMALS);
    }

    function testDepositWithoutApprove() public {
        // 未授权直接存款
        vm.prank(user);
        vm.expectRevert();
        bank.deposit(100 * 10**DECIMALS);
    }

    function testReceiveApprovalInvalidToken() public {
        // 用错误 token 地址回调
        vm.prank(user);
        vm.expectRevert("invalid token");
        bank.receiveApproval(user, 100 * 10**DECIMALS, address(0xdead), "");
    }

    function testTokensReceivedInvalidSender() public {
        // 用错误 sender 回调
        vm.expectRevert("only token contract");
        bank.tokensReceived(user, 100 * 10**DECIMALS, "");
    }
}