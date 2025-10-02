// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract Bank {
    address public admin;
    mapping(address => uint256) public deposits;
    address[3] public top3Depositors;
    
    event Deposit(address indexed user, uint256 amount);
    event Withdrawal(address indexed admin, uint256 amount);
    
    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can call this function");
        _;
    }
    
    constructor() {
        admin = msg.sender;
    }
    
    // 接收直接转账存款
    receive() external payable {
        deposit();
    }
    
    // 存款函数
    function deposit() public payable {
        require(msg.value > 0, "Deposit amount must be greater than 0");
        
        deposits[msg.sender] += msg.value;
        updateTop3Depositors(msg.sender);
        
        emit Deposit(msg.sender, msg.value);
    }
    
    // 更新前3名存款用户
    function updateTop3Depositors(address depositor) internal {
        uint256 userDeposit = deposits[depositor];
        
        // 检查用户是否已在前3名中
        int256 existingIndex = -1;
        for (uint i = 0; i < 3; i++) {
            if (top3Depositors[i] == depositor) {
                existingIndex = int256(i);
                break;
            }
        }
        
        // 如果用户已在列表中，先移除
        if (existingIndex >= 0) {
            // 向前移动后面的元素
            for (uint i = uint256(existingIndex); i < 2; i++) {
                top3Depositors[i] = top3Depositors[i + 1];
            }
            top3Depositors[2] = address(0);
        }
        
        // 找到合适的插入位置
        uint256 insertPos = 3; // 默认不插入
        for (uint i = 0; i < 3; i++) {
            if (top3Depositors[i] == address(0) || deposits[top3Depositors[i]] < userDeposit) {
                insertPos = i;
                break;
            }
        }
        
        // 如果找到插入位置，插入用户
        if (insertPos < 3) {
            // 向后移动元素为新用户腾出空间
            for (uint i = 2; i > insertPos; i--) {
                top3Depositors[i] = top3Depositors[i - 1];
            }
            top3Depositors[insertPos] = depositor;
        }
    }
    

    
    // 仅管理员可以提取资金
    function withdraw(uint256 amount) external onlyAdmin {
        require(amount <= address(this).balance, "Insufficient balance");
        
        payable(admin).transfer(amount);
        
        emit Withdrawal(admin, amount);
    }
    
    // 提取所有资金
    function withdrawAll() external onlyAdmin {
        uint256 balance = address(this).balance;
        require(balance > 0, "No balance to withdraw");
        
        payable(admin).transfer(balance);
        
        emit Withdrawal(admin, balance);
    }
    
    // 查看合约余额
    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }
    
    // 查看用户存款金额
    function getUserDeposit(address user) external view returns (uint256) {
        return deposits[user];
    }
    
    // 获取前3名存款用户
    function getTop3Depositors() external view returns (address[3] memory, uint256[3] memory) {
        uint256[3] memory amounts;
        for (uint i = 0; i < 3; i++) {
            amounts[i] = deposits[top3Depositors[i]];
        }
        return (top3Depositors, amounts);
    }
}