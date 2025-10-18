// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// TokenBank - 代币银行合约
// 功能：用户可以存入和取出 ERC20 代币
// 安全特性：防重入、可暂停、权限控制、安全的代币转账
contract TokenBank is ReentrancyGuard, Pausable, Ownable {
    using SafeERC20 for IERC20;

    // ============================================
    // 自定义错误（节省 gas）
    // ============================================
    error AmountZero();              // 金额不能为 0
    error InsufficientBalance();     // 余额不足

    // ============================================
    // 状态变量
    // ============================================
    // 支持的代币合约（immutable 节省 gas）
    IERC20 public immutable token;

    // 用户存款余额
    mapping(address => uint256) private balances;

    // 总存款量
    uint256 public totalDeposits;

    // ============================================
    // 事件
    // ============================================
    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);

    // ============================================
    // 构造函数
    // ============================================
    // _token: 要支持的 ERC20 代币地址
    constructor(IERC20 _token) Ownable(msg.sender) {
        token = _token;
    }

    // ============================================
    // 管理员功能
    // ============================================

    // 暂停合约（紧急情况使用）
    function pause() external onlyOwner {
        _pause();
    }

    // 恢复合约
    function unpause() external onlyOwner {
        _unpause();
    }

    // ============================================
    // 存款功能
    // ============================================

    // 存入代币
    // amount: 存款金额
    // 注意：调用前需要先 approve 授权给本合约
    function deposit(uint256 amount) external nonReentrant whenNotPaused {
        // 检查金额
        if (amount == 0) revert AmountZero();

        // 使用 SafeERC20 安全转入代币
        token.safeTransferFrom(msg.sender, address(this), amount);

        // 更新余额
        balances[msg.sender] += amount;
        totalDeposits += amount;

        emit Deposit(msg.sender, amount);
    }

    // ============================================
    // 取款功能
    // ============================================

    // 取出代币
    // amount: 取款金额
    function withdraw(uint256 amount) external nonReentrant whenNotPaused {
        // 检查金额
        if (amount == 0) revert AmountZero();

        // 检查余额
        if (balances[msg.sender] < amount) revert InsufficientBalance();

        // 先更新状态（防重入）
        balances[msg.sender] -= amount;
        totalDeposits -= amount;

        // 使用 SafeERC20 安全转出代币
        token.safeTransfer(msg.sender, amount);

        emit Withdraw(msg.sender, amount);
    }

    // ============================================
    // 查询功能
    // ============================================

    // 查询用户余额
    function balanceOf(address user) external view returns (uint256) {
        return balances[user];
    }

    // 查询合约持有的代币总量（应该等于 totalDeposits）
    function getContractBalance() external view returns (uint256) {
        return token.balanceOf(address(this));
    }
}
