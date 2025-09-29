pragma solidity ^0.8.0;

import "./interfaces.sol";

contract TokenBank is ITokenRecipient, ITokenCallback {
    IERC20 public token;
    mapping(address => uint256) private deposits;

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);

    constructor(IERC20 _token) {
        token = _token;
    }

    // 标准存款（需先 approve）
    function deposit(uint256 _amount) external {
        require(_amount > 0, "amount zero");
        bool ok = token.transferFrom(msg.sender, address(this), _amount);
        require(ok, "transferFrom failed");
        deposits[msg.sender] += _amount;
        emit Deposit(msg.sender, _amount);
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
        bool ok = token.transferFrom(_from, address(this), _value);
        require(ok, "transferFrom failed in callback");
        deposits[_from] += _value;
        emit Deposit(_from, _value);
    }

    // 支持 tokensReceived 钩子（用于 transferWithCallback）
    function tokensReceived(address from, uint256 amount, bytes calldata /* data */) external override {
        require(msg.sender == address(token), "only token contract");
        require(amount > 0, "amount zero");
        deposits[from] += amount;
        emit Deposit(from, amount);
    }

    // 从银行提取之前存入的代币
    function withdraw(uint256 _amount) external {
        require(_amount > 0, "amount zero");
        require(deposits[msg.sender] >= _amount, "insufficient balance");
        deposits[msg.sender] -= _amount;
        bool ok = token.transfer(msg.sender, _amount);
        require(ok, "transfer failed");
        emit Withdraw(msg.sender, _amount);
    }

    // 查询用户在银行的存款余额
    function balanceOf(address _user) external view returns (uint256) {
        return deposits[_user];
    }
}