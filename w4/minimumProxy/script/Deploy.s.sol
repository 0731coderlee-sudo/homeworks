// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/MemeFactory.sol";
import "../src/MemeToken.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        
        // 1. 部署工厂合约
        MemeFactory factory = new MemeFactory();
        console.log("MemeFactory deployed at:", address(factory));
        console.log("Implementation deployed at:", factory.implementation());
        console.log("Project owner:", factory.projectOwner());
        
        vm.stopBroadcast();
    }
}

contract CreateMemeScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address factoryAddress = vm.envAddress("FACTORY_ADDRESS");
        
        vm.startBroadcast(deployerPrivateKey);
        
        MemeFactory factory = MemeFactory(factoryAddress);
        
        // 2. 创建 Meme 代币
        address memeToken = factory.deployMeme(
            "PEPE",              // symbol
            1000000 * 1e18,      // totalSupply: 1,000,000 tokens
            1000 * 1e18,         // perMint: 1,000 tokens per mint
            0.001 ether          // price: 0.001 ETH per token
        );
        
        console.log("Meme Token deployed at:", memeToken);
        
        MemeToken token = MemeToken(memeToken);
        console.log("Symbol:", token.symbol());
        console.log("Total Supply:", token.totalSupply());
        console.log("Per Mint:", token.perMint());
        console.log("Price:", token.price());
        console.log("Creator:", token.creator());
        
        vm.stopBroadcast();
    }
}