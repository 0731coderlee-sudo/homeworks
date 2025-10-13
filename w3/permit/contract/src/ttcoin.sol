// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20, ITokenRecipient, ITokenCallback, IERC20Permit} from "./interfaces.sol";


contract ttcoin is IERC20, IERC20Permit {
    string public override name;
    string public override symbol;
    uint8 public override decimals = 18;
    uint256 public override totalSupply;

    mapping(address => uint256) public override balanceOf;
    mapping(address => mapping(address => uint256)) public override allowance;

    // EIP-2612: Permit 相关
    mapping(address => uint256) public override nonces;
    bytes32 private immutable _CACHED_DOMAIN_SEPARATOR;
    uint256 private immutable _CACHED_CHAIN_ID;
    address private immutable _CACHED_THIS;

    bytes32 private immutable _PERMIT_TYPEHASH;
    bytes32 private immutable _TYPE_HASH;

    event Burn(address indexed from, uint256 value);
    
    constructor(uint256 _initialSupply, string memory _tokenName, string memory _tokenSymbol) {
        totalSupply = _initialSupply * 10 ** uint256(decimals);
        balanceOf[msg.sender] = totalSupply;
        name = _tokenName;
        symbol = _tokenSymbol;

        // EIP-2612: 初始化 Permit 相关常量
        _PERMIT_TYPEHASH = keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
        _TYPE_HASH = keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

        _CACHED_CHAIN_ID = block.chainid;
        _CACHED_THIS = address(this);
        _CACHED_DOMAIN_SEPARATOR = _buildDomainSeparator(_TYPE_HASH, _tokenName);
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

    // 扩展transferwithcallback功能
    // 新增：带hook的转账函数
    function transferWithCallback(address _to, uint256 _value, bytes calldata _data) public returns (bool) {
        // 先执行标准转账
        _transfer(msg.sender, _to, _value);

        // 如果目标地址是合约，则调用 tokensReceived 回调
        if (isContract(_to)) {
            try ITokenCallback(_to).tokensReceived(msg.sender, _value, _data) {
                // 回调成功
            } catch Error(string memory reason) {
                revert(reason);
            } catch {
                revert("tokensReceived callback failed");
            }
        }

        return true;
    }

    // 辅助函数：判断是否为合约地址
    function isContract(address _addr) internal view returns (bool) {
        uint256 size;
        assembly { size := extcodesize(_addr) }
        return size > 0;
    }

    // ==================== EIP-2612: Permit 功能 ====================

    /// @notice 返回当前的 DOMAIN_SEPARATOR
    /// @dev 如果链ID改变（如分叉），会重新计算
    function DOMAIN_SEPARATOR() public view override returns (bytes32) {
        if (block.chainid == _CACHED_CHAIN_ID && address(this) == _CACHED_THIS) {
            return _CACHED_DOMAIN_SEPARATOR;
        } else {
            return _buildDomainSeparator(_TYPE_HASH, name);
        }
    }

    /// @dev 构建 EIP-712 Domain Separator
    function _buildDomainSeparator(bytes32 typeHash, string memory tokenName) private view returns (bytes32) {
        return keccak256(
            abi.encode(
                typeHash,
                keccak256(bytes(tokenName)),
                keccak256(bytes("1")),  // version
                block.chainid,
                address(this)
            )
        );
    }

    /// @notice EIP-2612 permit 函数：通过签名授权
    /// @param owner 代币所有者
    /// @param spender 被授权的地址
    /// @param value 授权额度
    /// @param deadline 签名过期时间
    /// @param v 签名参数
    /// @param r 签名参数
    /// @param s 签名参数
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external override {
        require(deadline >= block.timestamp, "ttcoin: permit expired");

        // 构造 EIP-712 结构化数据哈希
        bytes32 structHash = keccak256(
            abi.encode(
                _PERMIT_TYPEHASH,
                owner,
                spender,
                value,
                nonces[owner]++,  // 使用后自增，防止重放攻击
                deadline
            )
        );

        // 构造最终的签名消息
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",  // EIP-712 前缀
                DOMAIN_SEPARATOR(),
                structHash
            )
        );

        // 恢复签名者地址
        address recoveredAddress = ecrecover(digest, v, r, s);
        require(recoveredAddress != address(0), "ttcoin: invalid signature");
        require(recoveredAddress == owner, "ttcoin: unauthorized");

        // 执行授权
        allowance[owner][spender] = value;
        emit Approval(owner, spender, value);
    }

}