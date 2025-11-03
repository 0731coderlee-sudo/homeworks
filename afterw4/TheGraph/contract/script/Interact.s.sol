// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";
import {BaseERC721} from "../src/BaseERC721.sol";
import {NFTMarket} from "../src/NFTMarket.sol";
import {ttcoin} from "../src/ttcoin.sol";
import {IERC20} from "../src/interfaces.sol";

contract InteractScript is Script {
    // 已部署的合约地址
    address constant NFT_ADDRESS = 0x158B8910808a681AC2A35506753f617b0fc440D1;
    address constant MARKET_ADDRESS = 0x543D6e9c9c7b1D9F5A21601EeBDC023B17fdB6DC;
    address constant TTC_ADDRESS = 0x4BB3DbF015c1CFF5ACF085FC74fbF71059635688;

    BaseERC721 nft;
    NFTMarket market;
    ttcoin ttc;

    function setUp() public {
        nft = BaseERC721(NFT_ADDRESS);
        market = NFTMarket(MARKET_ADDRESS);
        ttc = ttcoin(TTC_ADDRESS);
    }

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        // 尝试读取买家私钥（可选）
        // 如果设置了 BUYER_PRIVATE_KEY，使用不同账户购买；否则使用 deployer 账户
        bool hasBuyer = false;
        address buyer = deployer;
        uint256 buyerPrivateKey;
        
        try vm.envUint("BUYER_PRIVATE_KEY") returns (uint256 key) {
            buyerPrivateKey = key;
            buyer = vm.addr(buyerPrivateKey);
            hasBuyer = true;
        } catch {
            // 如果没有设置 BUYER_PRIVATE_KEY，使用 deployer 作为买家
            hasBuyer = false;
        }
        
        vm.startBroadcast(deployerPrivateKey);

        console.log("=== Start generating NFT transaction records ===");
        console.log("Deployer:", deployer);
        console.log("Buyer:", buyer);

        // ============================================
        // Step 1: Mint NFTs
        // ============================================
        console.log("\n--- Step 1: Mint NFTs ---");
        uint256 tokenId1 = 111;
        uint256 tokenId2 = 222;
        uint256 tokenId3 = 333;
        
        // Use mintWithURI to create NFTs with custom URIs
        string memory uri1 = string(abi.encodePacked("https://api.example.com/metadata/", vm.toString(tokenId1)));
        string memory uri2 = string(abi.encodePacked("https://api.example.com/metadata/", vm.toString(tokenId2)));
        string memory uri3 = string(abi.encodePacked("https://api.example.com/metadata/", vm.toString(tokenId3)));
        
        nft.mintWithURI(deployer, tokenId1, uri1);
        console.log("Minted NFT #1 to", deployer);
        
        nft.mintWithURI(deployer, tokenId2, uri2);
        console.log("Minted NFT #2 to", deployer);
        
        nft.mintWithURI(deployer, tokenId3, uri3);
        console.log("Minted NFT #3 to", deployer);

        // ============================================
        // Step 2: Approve market contract to transfer NFTs
        // ============================================
        console.log("\n--- Step 2: Approve market contract ---");
        nft.setApprovalForAll(MARKET_ADDRESS, true);
        console.log("Approved market to transfer NFTs");

        // ============================================
        // Step 3: List NFTs (emit Listed events)
        // ============================================
        console.log("\n--- Step 3: List NFTs ---");
        
        // List NFT #1, price 100 TTCoin (Note: TTCoin has 18 decimals)
        uint256 price1 = 100 * 10**18;
        market.list(NFT_ADDRESS, tokenId1, price1);
        console.log("Listed NFT #1 at price:", price1);
        
        // List NFT #2, price 200 TTCoin
        uint256 price2 = 200 * 10**18;
        market.list(NFT_ADDRESS, tokenId2, price2);
        console.log("Listed NFT #2 at price:", price2);

        // ============================================
        // Step 4: Prepare for purchase
        // ============================================
        console.log("\n--- Step 4: Prepare for purchase ---");
        
        if (hasBuyer && buyer != deployer) {
            // If using different buyer account, need to:
            // 1. Transfer some TTCoin to buyer
            // 2. Switch to buyer account
            // 3. Buyer approves market contract to use TTCoin
            
            uint256 amountForBuyer = 1000 * 10**18; // Transfer 1000 TTCoin to buyer
            ttc.transfer(buyer, amountForBuyer);
            console.log("Transferred TTCoin to buyer:", amountForBuyer);
            
            // Switch to buyer account
            vm.stopBroadcast();
            vm.startBroadcast(buyerPrivateKey);
            
            // Buyer approves market contract to use TTCoin
            ttc.approve(MARKET_ADDRESS, type(uint256).max);
            console.log("Buyer approved market to spend TTCoin");
        } else {
            // Use same account, directly approve
            ttc.approve(MARKET_ADDRESS, type(uint256).max);
            console.log("Approved market to spend TTCoin");
        }

        // ============================================
        // Step 5: Buy NFT (emit Bought event)
        // ============================================
        console.log("\n--- Step 5: Buy NFT ---");
        
        // Buy NFT #1
        market.buyNFT(NFT_ADDRESS, tokenId1);
        console.log("Bought NFT #1");
        
        // Switch back to deployer account for subsequent operations if needed
        if (hasBuyer && buyer != deployer) {
            vm.stopBroadcast();
            vm.startBroadcast(deployerPrivateKey);
        }

        // ============================================
        // Step 6: List NFT #3 (show more listing records)
        // ============================================
        console.log("\n--- Step 6: List more NFTs ---");
        
        uint256 price3 = 300 * 10**18;
        market.list(NFT_ADDRESS, tokenId3, price3);
        console.log("Listed NFT #3 at price:", price3);

        vm.stopBroadcast();

        console.log("\n=== Transaction records generation completed ===");
        console.log("NFT Contract:", NFT_ADDRESS);
        console.log("Market Contract:", MARKET_ADDRESS);
        console.log("TTCoin Contract:", TTC_ADDRESS);
        console.log("\nGenerated records include:");
        console.log("- 3 NFT mint events");
        console.log("- 3 listing events (Listed)");
        console.log("- 1 purchase event (Bought)");
    }
}

