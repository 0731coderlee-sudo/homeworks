// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/ttcoin.sol";
import "../src/tokenbank.sol";
import "../src/SimplePermit2.sol";

contract TokenBankTest is Test {
    ttcoin public token;
    TokenBank public bank;
    SimplePermit2 public permit2;

    address public owner;
    address public user1;
    address public user2;

    uint256 public user1PrivateKey;
    uint256 public user2PrivateKey;

    uint256 constant INITIAL_SUPPLY = 1_000_000;
    uint256 constant DECIMALS = 18;

    function setUp() public {
        // 生成可签名的地址
        (user1, user1PrivateKey) = makeAddrAndKey("user1");
        (user2, user2PrivateKey) = makeAddrAndKey("user2");
        owner = makeAddr("owner");

        // 部署代币
        vm.prank(owner);
        token = new ttcoin(INITIAL_SUPPLY, "Test Token", "TT");

        // 部署 Permit2
        permit2 = new SimplePermit2();

        // 部署银行
        bank = new TokenBank(IERC20(address(token)), IPermit2(address(permit2)));

        // 给 user1 和 user2 分配代币
        vm.startPrank(owner);
        token.transfer(user1, 10000 * 10**DECIMALS);
        token.transfer(user2, 10000 * 10**DECIMALS);
        vm.stopPrank();
    }

    // ==================== 基础功能测试 ====================

    function testDepositWithApprove() public {
        uint256 depositAmount = 1000 * 10**DECIMALS;

        vm.startPrank(user1);
        token.approve(address(bank), depositAmount);
        bank.deposit(depositAmount);
        vm.stopPrank();

        assertEq(bank.balanceOf(user1), depositAmount, "Bank balance incorrect");
        assertEq(token.balanceOf(address(bank)), depositAmount, "Bank token balance incorrect");
    }

    function testWithdraw() public {
        uint256 depositAmount = 1000 * 10**DECIMALS;

        // 先存款
        vm.startPrank(user1);
        token.approve(address(bank), depositAmount);
        bank.deposit(depositAmount);

        // 再提现
        uint256 balanceBefore = token.balanceOf(user1);
        bank.withdraw(depositAmount);
        vm.stopPrank();

        assertEq(bank.balanceOf(user1), 0, "Bank balance should be 0");
        assertEq(token.balanceOf(user1), balanceBefore + depositAmount, "Token balance incorrect");
    }

    // ==================== 漏洞测试 ====================

    /// @notice 测试 transferWithCallback 无需授权即可存款
    function testTransferWithCallbackNoApprovalNeeded() public {
        uint256 transferAmount = 1000 * 10**DECIMALS;

        vm.startPrank(user1);

        uint256 user1BalanceBefore = token.balanceOf(user1);

        // 用户没有授权给 bank，只是通过 transferWithCallback 转账
        // 修复后：这应该成功，因为 transferWithCallback 已经转移了代币
        token.transferWithCallback(address(bank), transferAmount, "");

        vm.stopPrank();

        // 验证存款成功
        assertEq(bank.balanceOf(user1), transferAmount, "Deposit should succeed");
        assertEq(token.balanceOf(user1), user1BalanceBefore - transferAmount, "User balance updated");
    }

    /// @notice 测试 transferWithCallback 修复后的正确行为
    function testTransferWithCallbackFixed() public {
        uint256 transferAmount = 1000 * 10**DECIMALS;

        vm.startPrank(user1);

        uint256 user1BalanceBefore = token.balanceOf(user1);
        uint256 bankBalanceBefore = token.balanceOf(address(bank));
        uint256 bankRecordBefore = bank.balanceOf(user1);

        // 使用 transferWithCallback
        // 修复后：只转移 1x 代币，记录 1x 存款 ✅
        token.transferWithCallback(address(bank), transferAmount, "");

        vm.stopPrank();

        uint256 user1BalanceAfter = token.balanceOf(user1);
        uint256 bankBalanceAfter = token.balanceOf(address(bank));
        uint256 bankRecordAfter = bank.balanceOf(user1);

        // 用户损失了 1x 代币（正确）
        assertEq(user1BalanceBefore - user1BalanceAfter, transferAmount, "User should lose 1x tokens");

        // 银行收到了 1x 代币（正确）
        assertEq(bankBalanceAfter - bankBalanceBefore, transferAmount, "Bank should receive 1x tokens");

        // 银行记录了 1x 存款（正确）✅
        assertEq(bankRecordAfter - bankRecordBefore, transferAmount, "Bank should record 1x deposit");

        // 用户可以完整提取所有存款
        vm.prank(user1);
        bank.withdraw(bankRecordAfter);

        // 银行合约中没有锁定的代币（正确）
        assertEq(token.balanceOf(address(bank)), 0, "No tokens should be locked");
    }

    // ==================== ApproveAndCall 测试 ====================

    function testApproveAndCall() public {
        uint256 depositAmount = 1000 * 10**DECIMALS;

        vm.startPrank(user1);

        uint256 balanceBefore = token.balanceOf(user1);

        // approveAndCall 应该正常工作（只授权，不转移）
        token.approveAndCall(address(bank), depositAmount, "");

        vm.stopPrank();

        assertEq(bank.balanceOf(user1), depositAmount, "Bank balance incorrect");
        assertEq(token.balanceOf(user1), balanceBefore - depositAmount, "User balance incorrect");
    }

    // ==================== Permit 功能测试 ====================

    function testPermitDeposit() public {
        uint256 depositAmount = 1000 * 10**DECIMALS;
        uint256 deadline = block.timestamp + 1 hours;

        // 构造 permit 签名
        bytes32 PERMIT_TYPEHASH = keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

        bytes32 domainSeparator = token.DOMAIN_SEPARATOR();
        uint256 nonce = token.nonces(user1);

        bytes32 structHash = keccak256(abi.encode(
            PERMIT_TYPEHASH,
            user1,
            address(bank),
            depositAmount,
            nonce,
            deadline
        ));

        bytes32 digest = keccak256(abi.encodePacked(
            "\x19\x01",
            domainSeparator,
            structHash
        ));

        // 使用 user1 的私钥签名
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(user1PrivateKey, digest);

        // 任何人都可以提交这个签名（这是预期行为）
        uint256 balanceBefore = token.balanceOf(user1);

        bank.permitDeposit(user1, depositAmount, deadline, v, r, s);

        assertEq(bank.balanceOf(user1), depositAmount, "Bank balance incorrect");
        assertEq(token.balanceOf(user1), balanceBefore - depositAmount, "User balance incorrect");
    }

    function testPermitExpired() public {
        uint256 depositAmount = 1000 * 10**DECIMALS;
        uint256 deadline = block.timestamp - 1; // 已过期

        bytes32 PERMIT_TYPEHASH = keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
        bytes32 domainSeparator = token.DOMAIN_SEPARATOR();
        uint256 nonce = token.nonces(user1);

        bytes32 structHash = keccak256(abi.encode(
            PERMIT_TYPEHASH,
            user1,
            address(bank),
            depositAmount,
            nonce,
            deadline
        ));

        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(user1PrivateKey, digest);

        vm.expectRevert("ttcoin: permit expired");
        bank.permitDeposit(user1, depositAmount, deadline, v, r, s);
    }

    function testPermitReplay() public {
        uint256 depositAmount = 1000 * 10**DECIMALS;
        uint256 deadline = block.timestamp + 1 hours;

        bytes32 PERMIT_TYPEHASH = keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
        bytes32 domainSeparator = token.DOMAIN_SEPARATOR();
        uint256 nonce = token.nonces(user1);

        bytes32 structHash = keccak256(abi.encode(PERMIT_TYPEHASH, user1, address(bank), depositAmount, nonce, deadline));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(user1PrivateKey, digest);

        // 第一次调用成功
        bank.permitDeposit(user1, depositAmount, deadline, v, r, s);

        // 第二次调用应该失败（nonce 已改变）
        vm.expectRevert("ttcoin: unauthorized");
        bank.permitDeposit(user1, depositAmount, deadline, v, r, s);
    }
}
