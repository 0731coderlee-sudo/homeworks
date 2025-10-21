// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {AutomationCompatibleInterface} from "@chainlink/contracts/src/v0.8/automation/AutomationCompatible.sol";

/**
 * @title Bank
 * @notice 一个简单的银行合约，演示 Chainlink Automation 的自动化功能
 * @dev 当总存款达到阈值时，自动转移一半的资金到指定接收地址
 *
 * 核心功能：
 * 1. 用户可以存款（deposit）
 * 2. 用户可以提款（withdraw）
 * 3. 当总存款 >= 阈值时，Chainlink Automation 自动触发，转移一半资金给 owner
 * 4. Owner 可以修改阈值和接收地址
 *
 * ⚠️ 注意：这是一个 DEMO 合约，简化了余额管理
 * - 不追踪单个用户余额
 * - 自动转账会直接减少合约总余额
 * - 专注于验证 Chainlink Automation 的触发机制
 */
contract Bank is AutomationCompatibleInterface {

    // ========== 状态变量 ==========

    /// @notice 合约所有者
    address public owner;

    /// @notice 触发自动转账的阈值（单位：wei）
    uint256 public threshold;

    /// @notice 接收自动转账的地址
    address public recipient;

    /// @notice 用户余额映射（可选功能，用于提款）
    mapping(address => uint256) public balances;

    /// @notice 总存款金额
    uint256 public totalDeposits;

    // ========== 事件 ==========

    /// @notice 存款事件
    /// @param user 存款用户地址
    /// @param amount 存款金额
    /// @param newBalance 用户新余额
    /// @param totalDeposits 合约总存款
    event Deposited(
        address indexed user,
        uint256 amount,
        uint256 newBalance,
        uint256 totalDeposits
    );

    /// @notice 提款事件
    /// @param user 提款用户地址
    /// @param amount 提款金额
    /// @param remainingBalance 用户剩余余额
    event Withdrawn(
        address indexed user,
        uint256 amount,
        uint256 remainingBalance
    );

    /// @notice 自动转账事件（由 Chainlink Automation 触发）
    /// @param recipient 接收地址
    /// @param amount 转账金额
    /// @param remainingDeposits 剩余总存款
    /// @param timestamp 转账时间戳
    event AutoTransferred(
        address indexed recipient,
        uint256 amount,
        uint256 remainingDeposits,
        uint256 timestamp
    );

    /// @notice 阈值更新事件
    event ThresholdUpdated(uint256 oldThreshold, uint256 newThreshold);

    /// @notice 接收地址更新事件
    event RecipientUpdated(address indexed oldRecipient, address indexed newRecipient);

    // ========== 修饰器 ==========

    /// @notice 仅所有者可调用
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    // ========== 构造函数 ==========

    /// @notice 初始化 Bank 合约
    /// @param _threshold 触发自动转账的阈值
    /// @param _recipient 接收转账的地址
    constructor(uint256 _threshold, address _recipient) {
        require(_threshold > 0, "Threshold must be greater than 0");
        require(_recipient != address(0), "Invalid recipient address");

        owner = msg.sender;
        threshold = _threshold;
        recipient = _recipient;
    }

    // ========== 用户功能 ==========

    /// @notice 存款函数
    /// @dev 用户发送 ETH 到合约即可存款
    function deposit() external payable {
        require(msg.value > 0, "Deposit amount must be greater than 0");

        // 更新用户余额
        balances[msg.sender] += msg.value;

        // 更新总存款
        totalDeposits += msg.value;

        emit Deposited(msg.sender, msg.value, balances[msg.sender], totalDeposits);
    }

    /// @notice 提款函数
    /// @param amount 提款金额
    /// @dev 用户可以提取自己的存款
    function withdraw(uint256 amount) external {
        require(amount > 0, "Withdraw amount must be greater than 0");
        require(balances[msg.sender] >= amount, "Insufficient balance");

        // 更新用户余额
        balances[msg.sender] -= amount;

        // 更新总存款
        totalDeposits -= amount;

        // 转账给用户
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");

        emit Withdrawn(msg.sender, amount, balances[msg.sender]);
    }

    /// @notice 查询用户余额
    /// @param user 用户地址
    /// @return 用户余额
    function getBalance(address user) external view returns (uint256) {
        return balances[user];
    }

    /// @notice 获取合约实际 ETH 余额
    /// @return 合约余额
    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }

    // ========== Owner 管理功能 ==========

    /// @notice 设置新的阈值
    /// @param _threshold 新阈值
    function setThreshold(uint256 _threshold) external onlyOwner {
        require(_threshold > 0, "Threshold must be greater than 0");

        uint256 oldThreshold = threshold;
        threshold = _threshold;

        emit ThresholdUpdated(oldThreshold, _threshold);
    }

    /// @notice 设置新的接收地址
    /// @param _recipient 新接收地址
    function setRecipient(address _recipient) external onlyOwner {
        require(_recipient != address(0), "Invalid recipient address");

        address oldRecipient = recipient;
        recipient = _recipient;

        emit RecipientUpdated(oldRecipient, _recipient);
    }

    // ========== Chainlink Automation 接口 ==========

    /**
     * @notice Chainlink Automation 节点调用此函数检查是否需要执行 upkeep
     * @dev 这是一个 view 函数，链下调用，不消耗 gas
     * @return upkeepNeeded 如果总存款达到阈值，返回 true
     * @return performData 传递给 performUpkeep 的数据（此处未使用）
     */
    function checkUpkeep(
        bytes calldata /* checkData */
    )
        external
        view
        override
        returns (bool upkeepNeeded, bytes memory /* performData */)
    {
        // 检查是否达到阈值
        upkeepNeeded = totalDeposits >= threshold;

        // performData 可以用来传递额外信息，这里我们不需要
        // 返回空 bytes
    }

    /**
     * @notice Chainlink Automation 节点在 checkUpkeep 返回 true 时调用此函数
     * @dev 这是链上交易，会消耗 gas（由 Chainlink 支付）
     * @dev 执行自动转账：转移一半的总存款到接收地址
     */
    function performUpkeep(bytes calldata /* performData */) external override {
        // 🔒 安全检查：重新验证条件
        // 防止在 checkUpkeep 和 performUpkeep 之间状态发生变化
        if (totalDeposits >= threshold) {
            // 计算转账金额：总存款的一半
            uint256 transferAmount = totalDeposits / 2;

            // 更新总存款（减去转出的金额）
            totalDeposits -= transferAmount;

            // 转账到接收地址
            (bool success, ) = recipient.call{value: transferAmount}("");
            require(success, "Transfer to recipient failed");

            // 触发事件
            emit AutoTransferred(recipient, transferAmount, totalDeposits, block.timestamp);
        }

        // 注意：如果条件不满足（可能在检查和执行之间状态改变了），
        // 函数会静默返回，不会执行转账
    }

    // ========== 辅助函数 ==========

    /// @notice 接收 ETH 的回退函数
    /// @dev 允许合约直接接收 ETH
    receive() external payable {
        // 直接接收的 ETH 不计入任何用户余额
        // 只增加合约余额，不增加 totalDeposits
        // 这样可以防止意外触发自动转账
    }
}
