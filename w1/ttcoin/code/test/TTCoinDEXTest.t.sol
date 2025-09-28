// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../ttcoin.sol";
import "../dexdeoo.sol";

contract TTCoinDEXTest is Test {
    ttcoin public token;
    SimpleDEX public dex;
    
    address public alice = address(0x1);
    address public bob = address(0x2);
    address public charlie = address(0x3);
    address public test1 = address(0x4);
    address public testb = address(0x5);
    
    uint256 public constant INITIAL_SUPPLY = 1000000;
    uint256 public constant DECIMALS = 18;
    
    event TransferExecuted(address indexed from, address indexed to, uint256 amount, address token);
    event NotificationReceived(address indexed from, uint256 value, address token, string action);
    
    function setUp() public {
        // 部署TTCoin合约 - 1000000个代币，名称"TestToken"，符号"TT"
        token = new ttcoin(INITIAL_SUPPLY, "TestToken", "TT");
        
        // 部署SimpleDEX合约
        dex = new SimpleDEX();
        
        // 给Alice转一些代币进行测试
        uint256 aliceTokens = 10000 * 10**DECIMALS; // 10000个代币
        token.transfer(alice, aliceTokens);
        
        // 给Bob转一些代币
        uint256 bobTokens = 5000 * 10**DECIMALS; // 5000个代币  
        token.transfer(bob, bobTokens);
        
        // 给test1转一些代币进行测试
        uint256 test1Tokens = 3000 * 10**DECIMALS; // 3000个代币
        token.transfer(test1, test1Tokens);
        
        console.log("Setup completed:");
        console.log("TTCoin address:", address(token));
        console.log("SimpleDEX address:", address(dex));
        console.log("Alice balance:", token.balanceOf(alice) / 10**DECIMALS);
        console.log("Bob balance:", token.balanceOf(bob) / 10**DECIMALS);
        console.log("test1 balance:", token.balanceOf(test1) / 10**DECIMALS);
    }
    
    function testBasicTokenFunctions() public {
        // 测试基本的代币功能
        assertEq(token.name(), "TestToken");
        assertEq(token.symbol(), "TT");
        assertEq(token.decimals(), 18);
        assertEq(token.totalSupply(), INITIAL_SUPPLY * 10**DECIMALS);
        
        console.log("[PASS] Basic token functions test passed");
    }
    
    function testApproveAndCallTransfer() public {
        console.log("\n=== Testing approveAndCall Transfer ===");
        
        uint256 transferAmount = 500 * 10**DECIMALS; // 转账500个代币
        
        // 记录转账前的余额
        uint256 aliceBalanceBefore = token.balanceOf(alice);
        uint256 charlieBalanceBefore = token.balanceOf(charlie);
        
        console.log("Before transfer:");
        console.log("Alice balance:", aliceBalanceBefore / 10**DECIMALS);
        console.log("Charlie balance:", charlieBalanceBefore / 10**DECIMALS);
        
        // 准备extraData - 编码操作类型和接收者地址
        bytes memory extraData = abi.encode("TRANSFER", charlie);
        
        // 监听事件
        vm.expectEmit(true, true, true, true);
        emit NotificationReceived(alice, transferAmount, address(token), "TRANSFER");
        
        vm.expectEmit(true, true, true, true);
        emit TransferExecuted(alice, charlie, transferAmount, address(token));
        
        // Alice使用approveAndCall发送代币给Charlie
        vm.prank(alice);
        bool success = token.approveAndCall(address(dex), transferAmount, extraData);
        
        // 验证返回值
        assertTrue(success, "approveAndCall should return true");
        
        // 验证余额变化
        uint256 aliceBalanceAfter = token.balanceOf(alice);
        uint256 charlieBalanceAfter = token.balanceOf(charlie);
        
        assertEq(aliceBalanceAfter, aliceBalanceBefore - transferAmount, "Alice balance should decrease");
        assertEq(charlieBalanceAfter, charlieBalanceBefore + transferAmount, "Charlie balance should increase");
        
        console.log("After transfer:");
        console.log("Alice balance:", aliceBalanceAfter / 10**DECIMALS);
        console.log("Charlie balance:", charlieBalanceAfter / 10**DECIMALS);
        
        // 验证授权额度被消耗
        uint256 remainingAllowance = token.allowance(alice, address(dex));
        assertEq(remainingAllowance, 0, "Allowance should be consumed");
        
        console.log("[PASS] ApproveAndCall transfer test passed");
    }
    
    function testMultipleTransfers() public {
        console.log("\n=== Testing Multiple Transfers ===");
        
        uint256 transferAmount1 = 200 * 10**DECIMALS;
        uint256 transferAmount2 = 300 * 10**DECIMALS;
        
        // 第一次转账：Alice -> Charlie
        bytes memory extraData1 = abi.encode("TRANSFER", charlie);
        vm.prank(alice);
        token.approveAndCall(address(dex), transferAmount1, extraData1);
        
        // 第二次转账：Bob -> Charlie  
        bytes memory extraData2 = abi.encode("TRANSFER", charlie);
        vm.prank(bob);
        token.approveAndCall(address(dex), transferAmount2, extraData2);
        
        // 验证Charlie收到了两笔转账
        uint256 charlieBalance = token.balanceOf(charlie);
        uint256 expectedBalance = transferAmount1 + transferAmount2;
        assertEq(charlieBalance, expectedBalance, "Charlie should receive both transfers");
        
        console.log("Charlie total received:", charlieBalance / 10**DECIMALS);
        console.log("[PASS] Multiple transfers test passed");
    }
    
    function testDEXQueryFunctions() public {
        console.log("\n=== Testing DEX Query Functions ===");
        
        // 测试查询余额功能
        uint256 aliceBalance = dex.getUserBalance(alice, address(token));
        assertEq(aliceBalance, token.balanceOf(alice), "DEX should return correct balance");
        
        // 测试授权查询
        vm.prank(alice);
        token.approve(address(dex), 1000 * 10**DECIMALS);
        
        uint256 allowance = dex.getAllowance(alice, address(token));
        assertEq(allowance, 1000 * 10**DECIMALS, "DEX should return correct allowance");
        
        console.log("Alice balance via DEX:", aliceBalance / 10**DECIMALS);
        console.log("Alice allowance to DEX:", allowance / 10**DECIMALS);
        console.log("[PASS] DEX query functions test passed");
    }
    
    function test_InvalidAction() public {
        // 测试无效操作应该不执行任何操作
        console.log("\n=== Testing Invalid Action ===");
        
        uint256 transferAmount = 100 * 10**DECIMALS;
        bytes memory extraData = abi.encode("INVALID_ACTION", charlie);
        
        uint256 charlieBalanceBefore = token.balanceOf(charlie);
        
        vm.prank(alice);
        token.approveAndCall(address(dex), transferAmount, extraData);
        
        // Charlie的余额不应该改变
        uint256 charlieBalanceAfter = token.balanceOf(charlie);
        assertEq(charlieBalanceBefore, charlieBalanceAfter, "Charlie balance should not change for invalid action");
        
        console.log("[PASS] Invalid action test passed");
    }
    
    function testAuthorizeAndTransferToTestB() public {
        console.log("\n=== Testing test1 authorize DEX to transfer to testb ===");
        
        uint256 transferAmount = 1000 * 10**DECIMALS; // 转账1000个代币
        
        // 记录转账前的余额
        uint256 test1BalanceBefore = token.balanceOf(test1);
        uint256 testbBalanceBefore = token.balanceOf(testb);
        
        console.log("Before transfer:");
        console.log("test1 balance:", test1BalanceBefore / 10**DECIMALS);
        console.log("testb balance:", testbBalanceBefore / 10**DECIMALS);
        
        // 准备extraData - 编码操作类型和接收者地址
        bytes memory extraData = abi.encode("TRANSFER", testb);
        
        // 监听事件
        vm.expectEmit(true, true, true, true);
        emit NotificationReceived(test1, transferAmount, address(token), "TRANSFER");
        
        vm.expectEmit(true, true, true, true);
        emit TransferExecuted(test1, testb, transferAmount, address(token));
        
        // test1 使用 approveAndCall 授权 DEX 转账给 testb
        vm.prank(test1);
        bool success = token.approveAndCall(address(dex), transferAmount, extraData);
        
        // 验证返回值
        assertTrue(success, "approveAndCall should return true");
        
        // 验证余额变化
        uint256 test1BalanceAfter = token.balanceOf(test1);
        uint256 testbBalanceAfter = token.balanceOf(testb);
        
        assertEq(test1BalanceAfter, test1BalanceBefore - transferAmount, "test1 balance should decrease");
        assertEq(testbBalanceAfter, testbBalanceBefore + transferAmount, "testb balance should increase");
        
        console.log("After transfer:");
        console.log("test1 balance:", test1BalanceAfter / 10**DECIMALS);
        console.log("testb balance:", testbBalanceAfter / 10**DECIMALS);
        
        // 验证授权额度被消耗
        uint256 remainingAllowance = token.allowance(test1, address(dex));
        assertEq(remainingAllowance, 0, "Allowance should be consumed");
        
        console.log("[PASS] test1 authorize and transfer to testb test passed");
    }
}