// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/ttcoin.sol";
import "../src/tokenbank.sol";
import "../src/SimplePermit2.sol";

contract DeployAll is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // 1. 部署 SimplePermit2
        SimplePermit2 permit2 = new SimplePermit2();
        console.log("SimplePermit2 deployed at:", address(permit2));
        
        // 2. 部署 TTCoin
        ttcoin token = new ttcoin(1000000 * 10**18, "TT Coin", "TTC");
        console.log("TTCoin deployed at:", address(token));
        
        // 3. 部署 TokenBank（传入 token 和 permit2 地址）
        TokenBank bank = new TokenBank(IERC20(address(token)), IPermit2(address(permit2)));
        console.log("TokenBank deployed at:", address(bank));
        
        // 4. 给部署者转一些代币
        token.transfer(msg.sender, 10000 * 10**18);
        
        vm.stopBroadcast();
        
        console.log("\n=== Deployment Summary ===");
        console.log("SimplePermit2:", address(permit2));
        console.log("TTCoin:", address(token));
        console.log("TokenBank:", address(bank));
        console.log("Deployer:", msg.sender);
    }
}