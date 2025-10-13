// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/ttcoin.sol";

contract DistributeTokens is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address ttcoinAddress = 0x5FbDB2315678afecb367f032d93F642f64180aa3;
        
        vm.startBroadcast(deployerPrivateKey);
        
        ttcoin token = ttcoin(ttcoinAddress);
        
        // Anvil 的默认测试账户地址
        address[] memory testAccounts = new address[](9);
        testAccounts[0] = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8; // Account #1
        testAccounts[1] = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC; // Account #2
        testAccounts[2] = 0x90F79bf6EB2c4f870365E785982E1f101E93b906; // Account #3
        testAccounts[3] = 0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65; // Account #4
        testAccounts[4] = 0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc; // Account #5
        testAccounts[5] = 0x976EA74026E726554dB657fA54763abd0C3a0aa9; // Account #6
        testAccounts[6] = 0x14dC79964da2C08b23698B3D3cc7Ca32193d9955; // Account #7
        testAccounts[7] = 0x23618e81E3f5cdF7f54C3d65f7FBc0aBf5B21E8f; // Account #8
        testAccounts[8] = 0xa0Ee7A142d267C1f36714E4a8F75612F20a79720; // Account #9
        
        uint256 amountPerAccount = 10000 * 10**18; // 10,000 TTC per account
        
        for (uint i = 0; i < testAccounts.length; i++) {
            token.transfer(testAccounts[i], amountPerAccount);
            console.log("Sent", amountPerAccount / 10**18, "TTC to", testAccounts[i]);
        }
        
        vm.stopBroadcast();
        
        console.log("=== Token Distribution Complete ===");
        console.log("Each test account now has 10,000 TTC tokens");
    }
}