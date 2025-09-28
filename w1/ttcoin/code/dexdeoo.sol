
pragma solidity ^0.8.0;

import "./interfaces.sol";

// DEX合约 - 实现ITokenRecipient接口
contract SimpleDEX is ITokenRecipient {
    
    event TransferExecuted(address indexed from, address indexed to, uint256 amount, address token);
    event NotificationReceived(address indexed from, uint256 value, address token, string action);
    
    // 接收approveAndCall的通知
    function receiveApproval(
        address _from, 
        uint256 _value, 
        address _token, 
        bytes calldata _extraData
    ) external override {
        // 解析extraData - 期望格式: ("TRANSFER", recipient_address)
        (string memory action, address recipient) = abi.decode(_extraData, (string, address));
        
        emit NotificationReceived(_from, _value, _token, action);
        
        // 如果是转账操作
        if (keccak256(bytes(action)) == keccak256(bytes("TRANSFER"))) {
            _executeTransfer(_from, recipient, _value, _token);
        }
    }
    
    // 执行代币转账
    function _executeTransfer(address from, address to, uint256 amount, address tokenAddress) internal {
        // 使用DEX合约的授权额度执行transferFrom
        require(IERC20(tokenAddress).transferFrom(from, to, amount), "Transfer failed");
        
        emit TransferExecuted(from, to, amount, tokenAddress);
    }
    
    // 查询用户余额
    function getUserBalance(address user, address token) external view returns (uint256) {
        return IERC20(token).balanceOf(user);
    }
    
    // 查询DEX的授权额度
    function getAllowance(address owner, address token) external view returns (uint256) {
        return IERC20(token).allowance(owner, address(this));
    }
}
