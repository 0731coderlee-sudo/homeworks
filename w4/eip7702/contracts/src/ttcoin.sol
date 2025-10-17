// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

/**
 * @title TTCoin
 * @dev 使用 OpenZeppelin 库实现的 ERC20 代币
 * @notice 包含以下功能：
 * - 标准 ERC20 功能（transfer, approve, transferFrom）
 * - 可燃烧（Burnable）
 * - 无需 Gas 的授权（Permit - EIP-2612）
 */
contract TTCoin is ERC20, ERC20Burnable, ERC20Permit {
    /**
     * @dev 构造函数：初始化代币
     * @param initialSupply 初始供应量（不包含小数位）
     * @param tokenName 代币名称
     * @param tokenSymbol 代币符号
     */
    constructor(
        uint256 initialSupply,
        string memory tokenName,
        string memory tokenSymbol
    ) ERC20(tokenName, tokenSymbol) ERC20Permit(tokenName) {
        // 铸造初始供应量给部署者
        _mint(msg.sender, initialSupply * 10 ** decimals());
    }
}