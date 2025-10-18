// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title AirdropToken
 * @notice ERC20 token with Permit support for gasless approvals
 */
contract AirdropToken is ERC20, ERC20Permit, Ownable {
    constructor(
        string memory name,
        string memory symbol,
        uint256 initialSupply
    ) ERC20(name, symbol) ERC20Permit(name) Ownable(msg.sender) {
        _mint(msg.sender, initialSupply);
    }

    /**
     * @notice Mint new tokens (only owner)
     * @param to Address to receive tokens
     * @param amount Amount of tokens to mint
     */
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
}
