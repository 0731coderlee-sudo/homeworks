// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";
import {NFTMarket} from "../src/NFTMarket.sol";
import {ttcoin} from "../src/ttcoin.sol";

contract NFTMarketScript is Script {
    NFTMarket public market;

    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        // TTCoin 合约地址（从环境变量读取，如果没有则使用已部署的地址）
        address ttcoinAddress = vm.envOr(
            "TTC_ADDRESS",
            address(0x4BB3DbF015c1CFF5ACF085FC74fbF71059635688)
        );
        
        // NFT 合约地址（用于记录，构造函数不需要）
        address nftAddress = vm.envOr(
            "NFT_ADDRESS",
            address(0x158B8910808a681AC2A35506753f617b0fc440D1)
        );
        
        vm.startBroadcast(deployerPrivateKey);

        ttcoin ttcoinContract = ttcoin(ttcoinAddress);
        market = new NFTMarket(ttcoinContract);

        vm.stopBroadcast();
        
        // 输出部署信息
        console.log("NFTMarket deployed at:", address(market));
        console.log("TTCoin address:", ttcoinAddress);
        console.log("NFT contract address:", nftAddress);
    }
}

