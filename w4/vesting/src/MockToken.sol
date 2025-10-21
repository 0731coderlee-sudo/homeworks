// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title MockToken
 * @dev 用于测试的简单ERC20代币
 */
contract MockToken is ERC20 {
    constructor() ERC20("Mock Token", "MOCK") {
        // 铸造 1000万个代币给部署者
        _mint(msg.sender, 10_000_000 * 10 ** decimals());
    }

    /**
     * @dev 任何人都可以铸造代币(仅用于测试)
     */
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
