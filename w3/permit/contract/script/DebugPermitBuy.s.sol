// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/NFTMarket.sol";
import "../src/ttcoin.sol";

contract DebugPermitBuyScript is Script {
    function run() external view {
        // 合约地址（从重置脚本输出获取）
        NFTMarket nftMarket = NFTMarket(0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9);
        ttcoin token = ttcoin(0x5FbDB2315678afecb367f032d93F642f64180aa3);
        address nftAddress = 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512;
        
        // 检查的用户地址（Account #2）
        address buyer = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;
        uint256 tokenId = 1;
        
        console.log("=== Debug Permit Buy ===");
        
        // 1. 检查白名单状态
        bool isWhitelisted = nftMarket.isWhitelisted(buyer);
        console.log("Buyer whitelisted:", isWhitelisted);
        
        // 2. 检查NFT上架状态
        (address seller, uint256 price, address paymentToken) = nftMarket.getListing(nftAddress, tokenId);
        console.log("NFT listed:");
        console.log("  Seller:", seller);
        console.log("  Price:", price);
        console.log("  Payment Token:", paymentToken);
        console.log("  TTCoin address:", address(token));
        console.log("  Is listed:", price > 0);
        
        // 3. 检查买家代币余额
        uint256 buyerBalance = token.balanceOf(buyer);
        console.log("Buyer TTC balance:", buyerBalance);
        
        // 4. 检查买家nonce
        uint256 nonce = token.nonces(buyer);
        console.log("Buyer nonce:", nonce);
        
        // 5. 检查代币名称（用于域分隔符）
        string memory tokenName = token.name();
        console.log("Token name:", tokenName);
    }
}