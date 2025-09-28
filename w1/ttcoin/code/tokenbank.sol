pragma solidity ^0.8.0;

import "./interfaces.sol";

contract TokenBank {
    IERC20 public token;
    mapping(address => uint256) private deposits;

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);

    constructor(IERC20 _token) {
        token = _token;
    }

    // 将用户的 _amount 转入银行（用户需先调用 token.approve(TokenBank, _amount)）
    function deposit(uint256 _amount) external {
        require(_amount > 0, "amount zero");
        bool ok = token.transferFrom(msg.sender, address(this), _amount);
        require(ok, "transferFrom failed");
        deposits[msg.sender] += _amount;
        emit Deposit(msg.sender, _amount);
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