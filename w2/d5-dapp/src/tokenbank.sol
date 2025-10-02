// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.0;

import "./interfaces.sol";

contract TokenBank is ITokenRecipient, ITokenCallback {
    IERC20 public token;
    mapping(address => uint256) private deposits;
    address[] private depositors; // 存储所有存款用户的地址
    struct DepositRecord {
        address user;
        uint256 amount;
        uint256 timestamp;
    }
    DepositRecord[] private recentDeposits; // 存储最近的存款记录
    uint256 public constant MAX_RECENT_DEPOSITS = 10; // 限制最近记录的数量

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);

    constructor(IERC20 _token) {
        token = _token;
    }

    // 标准存款（需先 approve）
    function deposit(uint256 _amount) external {
        require(_amount > 0, "amount zero");
        _deposit(msg.sender, _amount);
    }

    // 支持 approveAndCall 一步存款
    function receiveApproval(
        address _from,
        uint256 _value,
        address _token,
        bytes calldata /* _extraData */
    ) external override {
        require(_token == address(token), "invalid token");
        require(msg.sender == address(token), "only token contract");
        require(_value > 0, "amount zero");
        _deposit(_from, _value);
    }

    // 支持 tokensReceived 钩子（用于 transferWithCallback）
    function tokensReceived(address from, uint256 amount, bytes calldata /* data */) external override {
        require(msg.sender == address(token), "only token contract");
        require(amount > 0, "amount zero");
        _deposit(from, amount);
    }

    // 从银行提取之前存入的代币
    function withdraw(uint256 _amount) external {
        require(_amount > 0, "amount zero");
        require(deposits[msg.sender] >= _amount, "insufficient balance");
        deposits[msg.sender] -= _amount;
        require(token.transfer(msg.sender, _amount), "transfer failed");
        emit Withdraw(msg.sender, _amount);
    }

    // 查询用户在银行的存款余额
    function balanceOf(address _user) external view returns (uint256) {
        return deposits[_user];
    }

    // 查询最近的存款记录
    function getRecentDeposits() external view returns (DepositRecord[] memory) {
        return recentDeposits;
    }

    // 私有函数：处理存款逻辑
    function _deposit(address _from, uint256 _amount) private {
        if (deposits[_from] == 0) {
            depositors.push(_from); // 新用户加入列表
        }
        require(token.transferFrom(_from, address(this), _amount), "transferFrom failed");
        deposits[_from] += _amount;
        emit Deposit(_from, _amount);

        // 添加到最近存款记录
        recentDeposits.push(DepositRecord({
            user: _from,
            amount: _amount,
            timestamp: block.timestamp
        }));

        // 保持最近记录的数量不超过 MAX_RECENT_DEPOSITS
        if (recentDeposits.length > MAX_RECENT_DEPOSITS) {
            for (uint256 i = 1; i < recentDeposits.length; i++) {
                recentDeposits[i - 1] = recentDeposits[i];
            }
            recentDeposits.pop();
        }
    }

    // 回退函数：防止意外接收 ETH
    fallback() external payable {
        revert("ETH not accepted");
    }

    receive() external payable {
        revert("ETH not accepted");
    }
}