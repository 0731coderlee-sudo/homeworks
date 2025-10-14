// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MemeToken {
    string public name = "Meme Token";
    string public symbol;
    uint8 public decimals = 18;
    
    uint256 public totalSupply;
    uint256 public perMint;
    uint256 public price;
    address public creator;
    uint256 public currentSupply;
    
    mapping(address => uint256) public balanceOf;
    
    event Transfer(address indexed from, address indexed to, uint256 value);
    
    // 初始化函数（代替构造函数）
    function initialize(
        string memory _symbol,
        uint256 _totalSupply,
        uint256 _perMint,
        uint256 _price,
        address _creator
    ) external {
        require(creator == address(0), "Already initialized");
        symbol = _symbol;
        totalSupply = _totalSupply;
        perMint = _perMint;
        price = _price;
        creator = _creator;
    }
    
    // 铸造代币
    function mint(address to, uint256 amount) external {
        require(currentSupply + amount <= totalSupply, "Exceeds total supply");
        balanceOf[to] += amount;
        currentSupply += amount;
        emit Transfer(address(0), to, amount);
    }
    
    // 简单的转账功能
    function transfer(address to, uint256 value) external returns (bool) {
        require(balanceOf[msg.sender] >= value, "Insufficient balance");
        balanceOf[msg.sender] -= value;
        balanceOf[to] += value;
        emit Transfer(msg.sender, to, value);
        return true;
    }
}