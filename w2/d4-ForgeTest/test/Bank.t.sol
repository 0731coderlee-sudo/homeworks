// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {Bank} from "../src/Bank.sol";

contract BankTest is Test {
    Bank public bank;
    address public admin;
    address public user1;
    address public user2;
    address public user3;
    address public user4;
    address public nonAdmin;

    event Deposit(address indexed user, uint256 amount);
    event Withdrawal(address indexed admin, uint256 amount);

    function setUp() public {
        admin = address(this);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        user3 = makeAddr("user3");
        user4 = makeAddr("user4");
        nonAdmin = makeAddr("nonAdmin");
        
        bank = new Bank();
        
        // 给测试账户一些ETH
        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);
        vm.deal(user3, 100 ether);
        vm.deal(user4, 100 ether);
        vm.deal(nonAdmin, 100 ether);
    }

    // ==================== 测试Case 1: 断言检查存款前后用户存款额更新 ====================
    
    function testDepositAmountUpdateCorrectly() public {
        // 初始存款应该为0
        assertEq(bank.getUserDeposit(user1), 0, "Initial deposit should be 0");
        assertEq(bank.getBalance(), 0, "Initial bank balance should be 0");
        
        // 第一次存款
        uint256 firstDeposit = 5 ether;
        vm.prank(user1);
        bank.deposit{value: firstDeposit}();
        
        assertEq(bank.getUserDeposit(user1), firstDeposit, "First deposit amount mismatch");
        assertEq(bank.getBalance(), firstDeposit, "Bank balance after first deposit mismatch");
        
        // 第二次存款（累加）
        uint256 secondDeposit = 3 ether;
        vm.prank(user1);
        bank.deposit{value: secondDeposit}();
        
        assertEq(bank.getUserDeposit(user1), firstDeposit + secondDeposit, "Cumulative deposit amount mismatch");
        assertEq(bank.getBalance(), firstDeposit + secondDeposit, "Bank balance after second deposit mismatch");
        
        // 其他用户存款不应影响user1的存款记录
        vm.prank(user2);
        bank.deposit{value: 2 ether}();
        
        assertEq(bank.getUserDeposit(user1), firstDeposit + secondDeposit, "User1 deposit should not change");
        assertEq(bank.getUserDeposit(user2), 2 ether, "User2 deposit amount mismatch");
        assertEq(bank.getBalance(), firstDeposit + secondDeposit + 2 ether, "Total bank balance mismatch");
    }
    
    function testDirectTransferDeposit() public {
        // 测试通过直接转账的存款更新
        uint256 depositAmount = 10 ether;
        uint256 userBalanceBefore = user1.balance;
        
        vm.prank(user1);
        (bool success,) = address(bank).call{value: depositAmount}("");
        require(success, "Direct transfer failed");
        
        assertEq(bank.getUserDeposit(user1), depositAmount, "Direct transfer deposit amount mismatch");
        assertEq(bank.getBalance(), depositAmount, "Bank balance after direct transfer mismatch");
        assertEq(user1.balance, userBalanceBefore - depositAmount, "User balance should decrease");
    }

    // ==================== 测试Case 2: 检查前3名用户排序 ====================
    
    function testTop3WithOneUser() public {
        // 只有1个用户存款
        vm.prank(user1);
        bank.deposit{value: 10 ether}();
        
        (address[3] memory topAddresses, uint256[3] memory topAmounts) = bank.getTop3Depositors();
        
        assertEq(topAddresses[0], user1, "First place should be user1");
        assertEq(topAmounts[0], 10 ether, "First place amount should be 10 ether");
        assertEq(topAddresses[1], address(0), "Second place should be empty");
        assertEq(topAmounts[1], 0, "Second place amount should be 0");
        assertEq(topAddresses[2], address(0), "Third place should be empty");
        assertEq(topAmounts[2], 0, "Third place amount should be 0");
    }
    
    function testTop3WithTwoUsers() public {
        // 2个用户存款
        vm.prank(user1);
        bank.deposit{value: 5 ether}();
        
        vm.prank(user2);
        bank.deposit{value: 8 ether}();
        
        (address[3] memory topAddresses, uint256[3] memory topAmounts) = bank.getTop3Depositors();
        
        // 应该按降序排列：user2(8), user1(5)
        assertEq(topAddresses[0], user2, "First place should be user2");
        assertEq(topAmounts[0], 8 ether, "First place amount should be 8 ether");
        assertEq(topAddresses[1], user1, "Second place should be user1");
        assertEq(topAmounts[1], 5 ether, "Second place amount should be 5 ether");
        assertEq(topAddresses[2], address(0), "Third place should be empty");
        assertEq(topAmounts[2], 0, "Third place amount should be 0");
    }
    
    function testTop3WithThreeUsers() public {
        // 3个用户存款
        vm.prank(user1);
        bank.deposit{value: 5 ether}();
        
        vm.prank(user2);
        bank.deposit{value: 8 ether}();
        
        vm.prank(user3);
        bank.deposit{value: 3 ether}();
        
        (address[3] memory topAddresses, uint256[3] memory topAmounts) = bank.getTop3Depositors();
        
        // 应该按降序排列：user2(8), user1(5), user3(3)
        assertEq(topAddresses[0], user2, "First place should be user2");
        assertEq(topAmounts[0], 8 ether, "First place amount should be 8 ether");
        assertEq(topAddresses[1], user1, "Second place should be user1");
        assertEq(topAmounts[1], 5 ether, "Second place amount should be 5 ether");
        assertEq(topAddresses[2], user3, "Third place should be user3");
        assertEq(topAmounts[2], 3 ether, "Third place amount should be 3 ether");
    }
    
    function testTop3WithFourUsers() public {
        // 4个用户存款，第4个用户应该挤掉最后一名
        vm.prank(user1);
        bank.deposit{value: 5 ether}();
        
        vm.prank(user2);
        bank.deposit{value: 8 ether}();
        
        vm.prank(user3);
        bank.deposit{value: 3 ether}();
        
        vm.prank(user4);
        bank.deposit{value: 6 ether}();
        
        (address[3] memory topAddresses, uint256[3] memory topAmounts) = bank.getTop3Depositors();
        
        // 应该按降序排列：user2(8), user4(6), user1(5)
        // user3(3)应该被挤出前3名
        assertEq(topAddresses[0], user2, "First place should be user2");
        assertEq(topAmounts[0], 8 ether, "First place amount should be 8 ether");
        assertEq(topAddresses[1], user4, "Second place should be user4");
        assertEq(topAmounts[1], 6 ether, "Second place amount should be 6 ether");
        assertEq(topAddresses[2], user1, "Third place should be user1");
        assertEq(topAmounts[2], 5 ether, "Third place amount should be 5 ether");
    }
    
    function testTop3WithSameUserMultipleDeposits() public {
        // 同一个用户多次存款
        vm.prank(user1);
        bank.deposit{value: 3 ether}();
        
        vm.prank(user2);
        bank.deposit{value: 5 ether}();
        
        vm.prank(user3);
        bank.deposit{value: 4 ether}();
        
        // user1再次存款，应该累加并重新排序
        vm.prank(user1);
        bank.deposit{value: 4 ether}(); // 总共7 ether
        
        (address[3] memory topAddresses, uint256[3] memory topAmounts) = bank.getTop3Depositors();
        
        // 应该按降序排列：user1(7), user2(5), user3(4)
        assertEq(topAddresses[0], user1, "First place should be user1");
        assertEq(topAmounts[0], 7 ether, "First place amount should be 7 ether");
        assertEq(topAddresses[1], user2, "Second place should be user2");
        assertEq(topAmounts[1], 5 ether, "Second place amount should be 5 ether");
        assertEq(topAddresses[2], user3, "Third place should be user3");
        assertEq(topAmounts[2], 4 ether, "Third place amount should be 4 ether");
    }

    // ==================== 测试Case 3: 检查只有管理员可取款 ====================
    
    function testOnlyAdminCanWithdraw() public {
        // 先存入一些资金
        vm.prank(user1);
        bank.deposit{value: 10 ether}();
        
        uint256 withdrawAmount = 5 ether;
        
        // 测试管理员可以成功提取
        uint256 adminBalanceBefore = admin.balance;
        bank.withdraw(withdrawAmount);
        assertEq(admin.balance, adminBalanceBefore + withdrawAmount, "Admin should receive withdrawn funds");
        assertEq(bank.getBalance(), 5 ether, "Bank balance should decrease");
        
        // 测试非管理员不能提取
        vm.prank(user1);
        vm.expectRevert("Only admin can call this function");
        bank.withdraw(1 ether);
        
        vm.prank(user2);
        vm.expectRevert("Only admin can call this function");
        bank.withdraw(1 ether);
        
        vm.prank(nonAdmin);
        vm.expectRevert("Only admin can call this function");
        bank.withdraw(1 ether);
    }
    
    function testOnlyAdminCanWithdrawAll() public {
        // 先存入一些资金
        vm.prank(user1);
        bank.deposit{value: 8 ether}();
        
        vm.prank(user2);
        bank.deposit{value: 12 ether}();
        
        uint256 totalBalance = bank.getBalance();
        assertEq(totalBalance, 20 ether, "Total balance should be 20 ether");
        
        // 测试管理员可以提取所有资金
        uint256 adminBalanceBefore = admin.balance;
        bank.withdrawAll();
        assertEq(admin.balance, adminBalanceBefore + totalBalance, "Admin should receive all funds");
        assertEq(bank.getBalance(), 0, "Bank balance should be 0 after withdrawAll");
        
        // 重新存款以测试非管理员
        vm.prank(user1);
        bank.deposit{value: 5 ether}();
        
        // 测试非管理员不能提取所有资金
        vm.prank(user1);
        vm.expectRevert("Only admin can call this function");
        bank.withdrawAll();
        
        vm.prank(nonAdmin);
        vm.expectRevert("Only admin can call this function");
        bank.withdrawAll();
    }
    
    function testWithdrawInsufficientBalance() public {
        // 存入少量资金
        vm.prank(user1);
        bank.deposit{value: 3 ether}();
        
        // 尝试提取超过余额的金额
        vm.expectRevert("Insufficient balance");
        bank.withdraw(5 ether);
    }
    
    function testWithdrawAllWithZeroBalance() public {
        // 没有存款时尝试提取所有资金
        vm.expectRevert("No balance to withdraw");
        bank.withdrawAll();
    }
    
    // ==================== 辅助测试函数 ====================
    
    function testDepositZeroAmount() public {
        vm.prank(user1);
        vm.expectRevert("Deposit amount must be greater than 0");
        bank.deposit{value: 0}();
    }
    
    function testEventsAreEmitted() public {
        // 测试存款事件
        vm.expectEmit(true, false, false, true);
        emit Deposit(user1, 5 ether);
        
        vm.prank(user1);
        bank.deposit{value: 5 ether}();
        
        // 测试提取事件
        vm.expectEmit(true, false, false, true);
        emit Withdrawal(admin, 2 ether);
        
        bank.withdraw(2 ether);
    }

    // 接收ETH的fallback函数
    receive() external payable {}
}