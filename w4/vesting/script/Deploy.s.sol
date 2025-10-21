// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/TokenVesting.sol";
import "../src/MockToken.sol";

/**
 * @title Deploy
 * @dev 部署脚本示例
 *
 * 使用方法:
 * forge script script/Deploy.s.sol:Deploy --rpc-url <your_rpc_url> --private-key <your_private_key> --broadcast
 */
contract Deploy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address beneficiary = vm.envAddress("BENEFICIARY");

        vm.startBroadcast(deployerPrivateKey);

        // 1. 部署代币
        MockToken token = new MockToken();
        console.log("Token deployed at:", address(token));

        // 2. 部署vesting合约 - 锁定100万代币
        uint256 vestingAmount = 1_000_000 * 10 ** token.decimals();
        TokenVesting vesting = new TokenVesting(
            beneficiary,
            address(token),
            vestingAmount
        );
        console.log("Vesting contract deployed at:", address(vesting));

        // 3. 转入代币到vesting合约
        token.transfer(address(vesting), vestingAmount);
        console.log("Transferred", vestingAmount, "tokens to vesting contract");

        vm.stopBroadcast();

        // 输出合约信息
        console.log("\n=== Deployment Summary ===");
        console.log("Token:", address(token));
        console.log("Vesting:", address(vesting));
        console.log("Beneficiary:", beneficiary);
        console.log("Vesting Amount:", vestingAmount);
        console.log("Cliff Duration:", vesting.CLIFF_DURATION() / 1 days, "days");
        console.log("Total Duration:", vesting.VESTING_DURATION() / 1 days, "days");
    }
}
