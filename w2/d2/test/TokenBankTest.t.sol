// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/tokenbank.sol";
import "../src/interfaces.sol";

contract MockERC20 is IERC20 {
    string public override name = "MockToken";
    string public override symbol = "MTK";
    uint8 public override decimals = 18;
    uint256 public override totalSupply;

    mapping(address => uint256) public override balanceOf;
    mapping(address => mapping(address => uint256)) public override allowance;

    constructor(uint256 _initialSupply) {
        totalSupply = _initialSupply;
        balanceOf[msg.sender] = _initialSupply;
    }

    function transfer(address _to, uint256 _value) public override returns (bool) {
        require(balanceOf[msg.sender] >= _value, "Insufficient balance");
        balanceOf[msg.sender] -= _value;
        balanceOf[_to] += _value;
        emit Transfer(msg.sender, _to, _value);
        return true;
    }

    function transferFrom(address _from, address _to, uint256 _value) public override returns (bool) {
        require(balanceOf[_from] >= _value, "Insufficient balance");
        require(allowance[_from][msg.sender] >= _value, "Allowance exceeded");
        balanceOf[_from] -= _value;
        allowance[_from][msg.sender] -= _value;
        balanceOf[_to] += _value;
        emit Transfer(_from, _to, _value);
        return true;
    }

    function approve(address _spender, uint256 _value) public override returns (bool) {
        allowance[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }
}

contract TokenBankTest is Test {
    TokenBank public bank;
    MockERC20 public token;

    address user1 = address(0x1);
    address user2 = address(0x2);

    function setUp() public {
        token = new MockERC20(1_000_000 ether);
        bank = new TokenBank(IERC20(address(token)));

        // 给测试合约分配足够的初始余额
        token.transfer(address(this), 500 ether);

        token.transfer(user1, 100 ether);
        token.transfer(user2, 200 ether);
    }

    function testDeposit() public {
        vm.startPrank(user1);
        token.approve(address(bank), 50 ether);
        bank.deposit(50 ether);
        assertEq(bank.balanceOf(user1), 50 ether);
        vm.stopPrank();
    }

    function testWithdraw() public {
        vm.startPrank(user1);
        token.approve(address(bank), 50 ether);
        bank.deposit(50 ether);
        bank.withdraw(30 ether);
        assertEq(bank.balanceOf(user1), 20 ether);
        assertEq(token.balanceOf(user1), 80 ether);
        vm.stopPrank();
    }

    function testRecentDeposits() public {
        vm.startPrank(user1);
        token.approve(address(bank), 50 ether);
        bank.deposit(50 ether);
        vm.stopPrank();

        vm.startPrank(user2);
        token.approve(address(bank), 100 ether);
        bank.deposit(100 ether);
        vm.stopPrank();

        TokenBank.DepositRecord[] memory records = bank.getRecentDeposits();
        assertEq(records.length, 2);
        assertEq(records[0].user, user1);
        assertEq(records[0].amount, 50 ether);
        assertEq(records[1].user, user2);
        assertEq(records[1].amount, 100 ether);
    }

    function testMaxRecentDeposits() public {
        for (uint256 i = 0; i < 12; i++) {
            address user = address(uint160(i + 1));
            token.transfer(user, 10 ether); // 确保用户有足够余额
            vm.startPrank(user);
            token.approve(address(bank), 10 ether);
            bank.deposit(10 ether);
            vm.stopPrank();
        }

        TokenBank.DepositRecord[] memory records = bank.getRecentDeposits();
        assertEq(records.length, 10);
        assertEq(records[0].user, address(3)); // 第三个用户开始记录
        assertEq(records[9].user, address(12)); // 最后一个用户
    }
}