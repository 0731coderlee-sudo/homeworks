// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";
import {ttcoin} from "../src/ttcoin.sol";

contract TTCoinScript is Script {
    ttcoin public ttcoinToken;

    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        // 从环境变量读取部署参数，如果没有则使用默认值
        uint256 initialSupply = vm.envOr("TTC_INITIAL_SUPPLY", uint256(1000000)); // 默认 100万
        string memory tokenName = vm.envOr("TTC_TOKEN_NAME", string("Test Token"));
        string memory tokenSymbol = vm.envOr("TTC_TOKEN_SYMBOL", string("TTC"));
        
        vm.startBroadcast(deployerPrivateKey);

        ttcoinToken = new ttcoin(initialSupply, tokenName, tokenSymbol);

        vm.stopBroadcast();
        
        // 输出部署信息
        console.log("TTCoin deployed at:", address(ttcoinToken));
        console.log("Token Name:", tokenName);
        console.log("Token Symbol:", tokenSymbol);
        console.log("Initial Supply:", initialSupply);
    }
}

