// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Script.sol";
import "../src/OpenspaceNFT.sol";

contract DeployOpenspaceNFT is Script {
    function run() external {
        vm.startBroadcast();
        
        // 部署合约
        OpenspaceNFT nft = new OpenspaceNFT();
        
        // 打印合约地址
        console.log("OpenspaceNFT deployed to:", address(nft));
        
        vm.stopBroadcast();
    }
}
