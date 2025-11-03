// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// 标准ERC20接口
interface IERC20 {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
    function totalSupply() external view returns (uint256);
    function balanceOf(address owner) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

// TokenRecipient接口 - 用于approveAndCall模式
interface ITokenRecipient { 
    function receiveApproval(address from, uint256 value, address token, bytes calldata extraData) external; 
}

// 可选的ERC677接口 - 用于transferWithCallback模式
interface ITokenCallback {
     function tokensReceived(address from, uint256 amount, bytes calldata data) external;
}