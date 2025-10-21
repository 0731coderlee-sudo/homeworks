// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {Bank} from "../src/Bank.sol";

/**
 * @title BankTest
 * @notice Bank 合约的测试套件
 *
 * 测试覆盖：
 * 1. 部署和初始化
 * 2. 存款功能
 * 3. 提款功能
 * 4. checkUpkeep 逻辑（阈值检查）
 * 5. performUpkeep 执行（自动转账）
 * 6. Owner 管理功能
 * 7. 边界条件和安全检查
 *
 * 运行测试：
 * forge test
 * forge test -vv          # 更详细的输出
 * forge test --match-test testDeposit  # 运行特定测试
 */
contract BankTest is Test {

    Bank public bank;
    address public owner;
    address public recipient;
    address public user1;
    address public user2;

    uint256 public constant THRESHOLD = 1 ether;
    uint256 public constant INITIAL_BALANCE = 10 ether;

    // ========== Setup ==========

    function setUp() public {
        // 设置测试账户
        owner = address(this);
        recipient = makeAddr("recipient");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        // 给测试用户充值
        vm.deal(user1, INITIAL_BALANCE);
        vm.deal(user2, INITIAL_BALANCE);

        // 部署合约
        bank = new Bank(THRESHOLD, recipient);
    }

    // ========== 部署测试 ==========

    function testInitialState() public view {
        assertEq(bank.owner(), owner);
        assertEq(bank.threshold(), THRESHOLD);
        assertEq(bank.recipient(), recipient);
        assertEq(bank.totalDeposits(), 0);
    }

    function testDeployWithZeroThreshold() public {
        vm.expectRevert("Threshold must be greater than 0");
        new Bank(0, recipient);
    }

    function testDeployWithZeroRecipient() public {
        vm.expectRevert("Invalid recipient address");
        new Bank(THRESHOLD, address(0));
    }

    // ========== 存款测试 ==========

    function testDeposit() public {
        uint256 depositAmount = 0.5 ether;

        vm.startPrank(user1);
        bank.deposit{value: depositAmount}();
        vm.stopPrank();

        assertEq(bank.balances(user1), depositAmount);
        assertEq(bank.totalDeposits(), depositAmount);
        assertEq(address(bank).balance, depositAmount);
    }

    function testMultipleDeposits() public {
        vm.prank(user1);
        bank.deposit{value: 0.3 ether}();

        vm.prank(user2);
        bank.deposit{value: 0.4 ether}();

        vm.prank(user1);
        bank.deposit{value: 0.2 ether}();

        assertEq(bank.balances(user1), 0.5 ether);
        assertEq(bank.balances(user2), 0.4 ether);
        assertEq(bank.totalDeposits(), 0.9 ether);
    }

    function testDepositZeroAmount() public {
        vm.startPrank(user1);
        vm.expectRevert("Deposit amount must be greater than 0");
        bank.deposit{value: 0}();
        vm.stopPrank();
    }

    function testDepositEmitsEvent() public {
        uint256 depositAmount = 0.5 ether;

        vm.expectEmit(true, false, false, true);
        emit Bank.Deposited(user1, depositAmount, depositAmount, depositAmount);

        vm.prank(user1);
        bank.deposit{value: depositAmount}();
    }

    // ========== 提款测试 ==========

    function testWithdraw() public {
        // 先存款
        vm.prank(user1);
        bank.deposit{value: 1 ether}();

        // 提款
        uint256 withdrawAmount = 0.4 ether;
        uint256 balanceBefore = user1.balance;

        vm.prank(user1);
        bank.withdraw(withdrawAmount);

        assertEq(bank.balances(user1), 0.6 ether);
        assertEq(bank.totalDeposits(), 0.6 ether);
        assertEq(user1.balance, balanceBefore + withdrawAmount);
    }

    function testWithdrawInsufficientBalance() public {
        vm.prank(user1);
        bank.deposit{value: 0.5 ether}();

        vm.prank(user1);
        vm.expectRevert("Insufficient balance");
        bank.withdraw(1 ether);
    }

    function testWithdrawZeroAmount() public {
        vm.prank(user1);
        bank.deposit{value: 1 ether}();

        vm.prank(user1);
        vm.expectRevert("Withdraw amount must be greater than 0");
        bank.withdraw(0);
    }

    // ========== checkUpkeep 测试 ==========

    function testCheckUpkeepReturnsFalseWhenBelowThreshold() public {
        // 存款低于阈值
        vm.prank(user1);
        bank.deposit{value: 0.5 ether}();

        (bool upkeepNeeded, ) = bank.checkUpkeep("");
        assertFalse(upkeepNeeded);
    }

    function testCheckUpkeepReturnsTrueWhenAtThreshold() public {
        // 存款等于阈值
        vm.prank(user1);
        bank.deposit{value: THRESHOLD}();

        (bool upkeepNeeded, ) = bank.checkUpkeep("");
        assertTrue(upkeepNeeded);
    }

    function testCheckUpkeepReturnsTrueWhenAboveThreshold() public {
        // 存款超过阈值
        vm.prank(user1);
        bank.deposit{value: 2 ether}();

        (bool upkeepNeeded, ) = bank.checkUpkeep("");
        assertTrue(upkeepNeeded);
    }

    // ========== performUpkeep 测试 ==========

    function testPerformUpkeepTransfersHalf() public {
        // 存入 2 ETH
        vm.prank(user1);
        bank.deposit{value: 2 ether}();

        uint256 recipientBalanceBefore = recipient.balance;

        // 执行 upkeep
        bank.performUpkeep("");

        // 验证转账了一半（1 ETH）
        assertEq(recipient.balance, recipientBalanceBefore + 1 ether);
        assertEq(bank.totalDeposits(), 1 ether);
        assertEq(address(bank).balance, 1 ether);
    }

    function testPerformUpkeepEmitsEvent() public {
        vm.prank(user1);
        bank.deposit{value: 2 ether}();

        vm.expectEmit(true, false, false, false);
        emit Bank.AutoTransferred(recipient, 1 ether, 1 ether, block.timestamp);

        bank.performUpkeep("");
    }

    function testPerformUpkeepDoesNothingBelowThreshold() public {
        // 存入低于阈值的金额
        vm.prank(user1);
        bank.deposit{value: 0.5 ether}();

        uint256 recipientBalanceBefore = recipient.balance;
        uint256 totalDepositsBefore = bank.totalDeposits();

        // 执行 upkeep（不应该有任何效果）
        bank.performUpkeep("");

        assertEq(recipient.balance, recipientBalanceBefore);
        assertEq(bank.totalDeposits(), totalDepositsBefore);
    }

    function testPerformUpkeepMultipleTimes() public {
        // 第一次：存入 2 ETH
        vm.prank(user1);
        bank.deposit{value: 2 ether}();

        bank.performUpkeep("");
        assertEq(bank.totalDeposits(), 1 ether);

        // 第二次：再存入 1 ETH，达到 2 ETH
        vm.prank(user2);
        bank.deposit{value: 1 ether}();

        bank.performUpkeep("");
        assertEq(bank.totalDeposits(), 1 ether);

        // 验证接收者总共收到 2 ETH（1 ETH + 1 ETH）
        assertEq(recipient.balance, 2 ether);
    }

    // ========== Owner 管理功能测试 ==========

    function testSetThreshold() public {
        uint256 newThreshold = 2 ether;

        bank.setThreshold(newThreshold);

        assertEq(bank.threshold(), newThreshold);
    }

    function testSetThresholdEmitsEvent() public {
        uint256 newThreshold = 2 ether;

        vm.expectEmit(false, false, false, true);
        emit Bank.ThresholdUpdated(THRESHOLD, newThreshold);

        bank.setThreshold(newThreshold);
    }

    function testSetThresholdOnlyOwner() public {
        vm.prank(user1);
        vm.expectRevert("Only owner can call this function");
        bank.setThreshold(2 ether);
    }

    function testSetThresholdZeroReverts() public {
        vm.expectRevert("Threshold must be greater than 0");
        bank.setThreshold(0);
    }

    function testSetRecipient() public {
        address newRecipient = makeAddr("newRecipient");

        bank.setRecipient(newRecipient);

        assertEq(bank.recipient(), newRecipient);
    }

    function testSetRecipientOnlyOwner() public {
        address newRecipient = makeAddr("newRecipient");

        vm.prank(user1);
        vm.expectRevert("Only owner can call this function");
        bank.setRecipient(newRecipient);
    }

    function testSetRecipientZeroAddressReverts() public {
        vm.expectRevert("Invalid recipient address");
        bank.setRecipient(address(0));
    }

    // ========== 完整流程测试 ==========

    function testCompleteWorkflow() public {
        // 1. 初始状态检查
        (bool upkeepNeeded, ) = bank.checkUpkeep("");
        assertFalse(upkeepNeeded);

        // 2. User1 存入 0.6 ETH
        vm.prank(user1);
        bank.deposit{value: 0.6 ether}();

        // 3. 仍然低于阈值
        (upkeepNeeded, ) = bank.checkUpkeep("");
        assertFalse(upkeepNeeded);

        // 4. User2 存入 0.8 ETH，总计 1.4 ETH，超过阈值
        vm.prank(user2);
        bank.deposit{value: 0.8 ether}();

        // 5. 现在应该触发 upkeep
        (upkeepNeeded, ) = bank.checkUpkeep("");
        assertTrue(upkeepNeeded);

        // 6. 执行自动转账
        bank.performUpkeep("");

        // 7. 验证结果
        assertEq(recipient.balance, 0.7 ether); // 1.4 / 2
        assertEq(bank.totalDeposits(), 0.7 ether);

        // 8. 现在低于阈值了
        (upkeepNeeded, ) = bank.checkUpkeep("");
        assertFalse(upkeepNeeded);
    }

    // ========== Fuzz 测试 ==========

    function testFuzzDeposit(uint256 amount) public {
        // 限制金额范围
        amount = bound(amount, 0.01 ether, 100 ether);

        vm.deal(user1, amount);

        vm.prank(user1);
        bank.deposit{value: amount}();

        assertEq(bank.balances(user1), amount);
        assertEq(bank.totalDeposits(), amount);
    }

    function testFuzzThreshold(uint256 newThreshold) public {
        // 限制阈值范围
        newThreshold = bound(newThreshold, 0.01 ether, 1000 ether);

        bank.setThreshold(newThreshold);

        assertEq(bank.threshold(), newThreshold);
    }

    // ========== 辅助函数 ==========

    // 允许测试合约接收 ETH
    receive() external payable {}
}
