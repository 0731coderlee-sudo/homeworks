// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

// TTCoin - 简洁的 ERC20 代币实现
// 使用 OpenZeppelin 标准库，提供基础的代币功能和销毁功能
contract ttcoin is ERC20, ERC20Burnable {

    // 构造函数：初始化代币名称、符号和初始供应量
    // _initialSupply: 初始供应量（会自动乘以 10^18）
    // _tokenName: 代币名称
    // _tokenSymbol: 代币符号
    constructor(
        uint256 _initialSupply,
        string memory _tokenName,
        string memory _tokenSymbol
    ) ERC20(_tokenName, _tokenSymbol) {
        // 铸造初始供应量给部署者
        _mint(msg.sender, _initialSupply * 10 ** decimals());
    }

    // 注意：以下功能由 OpenZeppelin 提供：
    // - transfer: 转账
    // - approve: 授权
    // - transferFrom: 从授权地址转账
    // - burn: 销毁自己的代币（来自 ERC20Burnable）
    // - burnFrom: 销毁授权的代币（来自 ERC20Burnable）
}
