// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title TokenBank
 * @dev 使用 OpenZeppelin 库实现的代币银行
 * @notice 支持多种存款方式：
 * - 标准存款（需要先 approve）
 * - Permit 存款（EIP-2612，无需预先授权）
 */
contract TokenBank is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    // ============ 状态变量 ============

    IERC20 public immutable token;
    
    mapping(address => uint256) private deposits;
    address[] private depositors;
    
    struct DepositRecord {
        address user;
        uint256 amount;
        uint256 timestamp;
    }

    // 环形缓冲区：使用固定大小数组提高性能
    uint256 public constant MAX_RECENT_DEPOSITS = 10;
    DepositRecord[MAX_RECENT_DEPOSITS] private recentDepositsBuffer;
    uint256 private depositIndex;  // 下一次写入的位置
    uint256 private depositCount;  // 已记录的存款数量（最多 MAX_RECENT_DEPOSITS）

    // ============ 事件 ============

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);

    // ============ 构造函数 ============
    
    /**
     * @dev 构造函数
     * @param _token ERC20 代币地址
     */
    constructor(address _token) Ownable(msg.sender) {
        require(_token != address(0), "TokenBank: zero address");
        token = IERC20(_token);
    }

    // ============ 存款函数 ============
    
    /**
     * @notice 标准存款（需要先 approve）
     * @param amount 存款金额
     */
    function deposit(uint256 amount) external nonReentrant {
        require(amount > 0, "TokenBank: amount is zero");
        
        // 使用 SafeERC20 安全转账
        token.safeTransferFrom(msg.sender, address(this), amount);
        
        _recordDeposit(msg.sender, amount);
    }

    /**
     * @notice 使用 EIP-2612 Permit 签名进行一键存款
     * @dev 通过离线签名授权并存款，避免两次交易
     * @param owner 代币所有者（签名者）
     * @param amount 存款金额
     * @param deadline 签名过期时间
     * @param v 签名参数
     * @param r 签名参数
     * @param s 签名参数
     */
    function permitDeposit(
        address owner,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external nonReentrant {
        require(amount > 0, "TokenBank: amount is zero");

        // 使用 permit 进行授权（消耗用户的离线签名）
        IERC20Permit(address(token)).permit(
            owner,
            address(this),
            amount,
            deadline,
            v,
            r,
            s
        );

        // 执行存款
        token.safeTransferFrom(owner, address(this), amount);
        _recordDeposit(owner, amount);
    }

    // ============ 提取函数 ============
    
    /**
     * @notice 从银行提取代币
     * @param amount 提取金额
     */
    function withdraw(uint256 amount) external nonReentrant {
        require(amount > 0, "TokenBank: amount is zero");
        require(deposits[msg.sender] >= amount, "TokenBank: insufficient balance");
        
        deposits[msg.sender] -= amount;
        
        // 使用 SafeERC20 安全转账
        token.safeTransfer(msg.sender, amount);
        
        emit Withdraw(msg.sender, amount);
    }

    // ============ 查询函数 ============
    
    /**
     * @notice 查询用户在银行的存款余额
     * @param user 用户地址
     * @return 存款余额
     */
    function balanceOf(address user) external view returns (uint256) {
        return deposits[user];
    }

    /**
     * @notice 查询最近的存款记录（按时间顺序，最旧的在前）
     * @return 最近存款记录数组
     */
    function getRecentDeposits() external view returns (DepositRecord[] memory) {
        DepositRecord[] memory result = new DepositRecord[](depositCount);

        if (depositCount == 0) {
            return result;
        }

        // 计算起始位置：如果缓冲区已满，从 depositIndex 开始读（最旧的）
        // 如果未满，从 0 开始读
        uint256 start = depositCount < MAX_RECENT_DEPOSITS ? 0 : depositIndex;

        for (uint256 i = 0; i < depositCount; i++) {
            result[i] = recentDepositsBuffer[(start + i) % MAX_RECENT_DEPOSITS];
        }

        return result;
    }

    /**
     * @notice 查询所有存款用户地址
     * @return 存款用户地址数组
     */
    function getDepositors() external view returns (address[] memory) {
        return depositors;
    }

    /**
     * @notice 查询银行合约中的总存款
     * @return 总存款金额
     */
    function totalDeposits() external view returns (uint256) {
        return token.balanceOf(address(this));
    }

    // ============ 内部函数 ============
    
    /**
     * @dev 记录存款（代币已经转入合约）
     * @param user 存款用户
     * @param amount 存款金额
     */
    function _recordDeposit(address user, uint256 amount) private {
        // 如果是新用户，添加到列表
        if (deposits[user] == 0) {
            depositors.push(user);
        }

        deposits[user] += amount;
        emit Deposit(user, amount);

        // 使用环形缓冲区记录存款（O(1) 操作）
        recentDepositsBuffer[depositIndex] = DepositRecord({
            user: user,
            amount: amount,
            timestamp: block.timestamp
        });

        // 更新索引（环形）
        depositIndex = (depositIndex + 1) % MAX_RECENT_DEPOSITS;

        // 更新计数（最多 MAX_RECENT_DEPOSITS）
        if (depositCount < MAX_RECENT_DEPOSITS) {
            depositCount++;
        }
    }
}