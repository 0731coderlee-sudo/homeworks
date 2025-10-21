// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {Bank} from "../src/Bank.sol";

/**
 * @title DeployBank
 * @notice Foundry 部署脚本，用于部署 Bank 合约
 *
 * 使用方法：
 *
 * 1. 本地测试部署（Anvil）：
 *    forge script script/DeployBank.s.sol --rpc-url http://localhost:8545 --broadcast
 *
 * 2. Sepolia 测试网部署：
 *    forge script script/DeployBank.s.sol \
 *      --rpc-url $SEPOLIA_RPC_URL \
 *      --private-key $PRIVATE_KEY \
 *      --broadcast \
 *      --verify \
 *      --etherscan-api-key $ETHERSCAN_API_KEY
 *
 * 3. 使用环境变量：
 *    export THRESHOLD=100000000000000000  # 0.1 ETH in wei
 *    export RECIPIENT=0x...
 *    forge script script/DeployBank.s.sol --rpc-url sepolia --broadcast
 *
 * 环境变量：
 * - THRESHOLD: 触发自动转账的阈值（wei），默认 0.1 ETH
 * - RECIPIENT: 接收转账的地址，默认为部署者地址
 */
contract DeployBank is Script {

    /// @notice 默认阈值：0.025 ETH
    uint256 public constant DEFAULT_THRESHOLD = 0.025 ether;

    function run() external returns (Bank) {
        // 从环境变量读取配置，如果没有则使用默认值
        uint256 threshold = vm.envOr("THRESHOLD", DEFAULT_THRESHOLD);
        address recipient = vm.envOr("RECIPIENT", msg.sender);

        console.log("========================================");
        console.log("Deploying Bank Contract");
        console.log("========================================");
        console.log("Deployer:", msg.sender);
        console.log("Threshold:", threshold, "wei");
        console.log("Threshold (ETH):", threshold / 1 ether);
        console.log("Recipient:", recipient);
        console.log("========================================");

        // 开始广播交易
        vm.startBroadcast();

        // 部署合约
        Bank bank = new Bank(threshold, recipient);

        // 停止广播
        vm.stopBroadcast();

        console.log("========================================");
        console.log("Bank Contract Deployed!");
        console.log("========================================");
        console.log("Contract Address:", address(bank));
        console.log("Owner:", bank.owner());
        console.log("Threshold:", bank.threshold());
        console.log("Recipient:", bank.recipient());
        console.log("========================================");
        console.log("");
        console.log("Next Steps:");
        console.log("1. Verify the contract on Etherscan (if not done automatically)");
        console.log("2. Register Upkeep on Chainlink Automation:");
        console.log("   https://automation.chain.link/");
        console.log("3. Fund your Upkeep with LINK tokens");
        console.log("4. Test by depositing ETH to reach the threshold");
        console.log("========================================");

        return bank;
    }
}
