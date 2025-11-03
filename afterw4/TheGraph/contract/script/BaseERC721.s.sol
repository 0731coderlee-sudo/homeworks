// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";
import {BaseERC721} from "../src/BaseERC721.sol";

contract BaseERC721Script is Script {
    BaseERC721 public nft;

    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        // 从环境变量读取部署参数，如果没有则使用默认值
        string memory nftName = vm.envOr("NFT_NAME", string("My NFT"));
        string memory nftSymbol = vm.envOr("NFT_SYMBOL", string("MNFT"));
        string memory baseURI = vm.envOr("NFT_BASE_URI", string("https://example.com/api/token/"));
        
        vm.startBroadcast(deployerPrivateKey);

        nft = new BaseERC721(nftName, nftSymbol, baseURI);

        vm.stopBroadcast();
        
        // 输出部署信息
        console.log("BaseERC721 deployed at:", address(nft));
        console.log("NFT Name:", nftName);
        console.log("NFT Symbol:", nftSymbol);
        console.log("Base URI:", baseURI);
    }
}

