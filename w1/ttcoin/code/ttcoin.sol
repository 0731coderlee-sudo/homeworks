// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.0;

import "./interfaces.sol";


contract ttcoin is IERC20 {
    string public override name;
    string public override symbol;
    uint8 public override decimals = 18;
    uint256 public override totalSupply;

    mapping(address => uint256) public override balanceOf;
    mapping(address => mapping(address => uint256)) public override allowance;

    event Burn(address indexed from, uint256 value);
    
    constructor(uint256 _initialSupply, string memory _tokenName, string memory _tokenSymbol) {
        totalSupply = _initialSupply * 10 ** uint256(decimals);
        balanceOf[msg.sender] = totalSupply;
        name = _tokenName;
        symbol = _tokenSymbol;
    }

    function _transfer(address _from, address _to, uint _value) internal {
        require(_from != address(0), "Transfer from zero address");
        require(_to != address(0), "Transfer to zero address");
        require(balanceOf[_from] >= _value, "Insufficient balance");
        
        uint256 previousBalances = balanceOf[_from] + balanceOf[_to];
        balanceOf[_from] -= _value;
        balanceOf[_to] += _value;
        
        // 断言检查（可选，用于调试）
        assert(balanceOf[_from] + balanceOf[_to] == previousBalances);
        
        emit Transfer(_from, _to, _value);
    }

    function transfer(address _to, uint256 _value) public override returns (bool success) {
        _transfer(msg.sender, _to, _value);
        return true;
    }

    function transferFrom(address _from, address _to, uint256 _value) public override returns (bool success) {
        require(_value <= allowance[_from][msg.sender], "Allowance exceeded");
        allowance[_from][msg.sender] -= _value;
        _transfer(_from, _to, _value);
        return true;
    }
·
    function approve(address _spender, uint256 _value) public override returns (bool success) {
        require(_spender != address(0), "Approve to zero address");
        allowance[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    function burn(uint256 _value) public returns (bool success) {
        require(balanceOf[msg.sender] >= _value, "Insufficient balance for burn");
        balanceOf[msg.sender] -= _value;
        totalSupply -= _value;
        emit Burn(msg.sender, _value);
        emit Transfer(msg.sender, address(0), _value);  // 添加Transfer事件
        return true;
    }

    function burnFrom(address _from, uint256 _value) public returns (bool success) {
        require(balanceOf[_from] >= _value, "Insufficient balance for burn");
        require(_value <= allowance[_from][msg.sender], "Allowance exceeded");
        balanceOf[_from] -= _value;
        allowance[_from][msg.sender] -= _value;
        totalSupply -= _value;
        emit Burn(_from, _value);
        emit Transfer(_from, address(0), _value);  // 添加Transfer事件
        return true;
    }

        // 添加到合约中
    function approveAndCall(address _spender, uint256 _value, bytes calldata _extraData) 
        public 
        returns (bool success) 
    {
        // 先执行标准授权
        require(approve(_spender, _value), "Approval failed");
        
        // 将地址转换为接口实例
        ITokenRecipient spender = ITokenRecipient(_spender);
        
        // 调用接收方的回调函数
        spender.receiveApproval(msg.sender, _value, address(this), _extraData);
        
        return true;
    }
}