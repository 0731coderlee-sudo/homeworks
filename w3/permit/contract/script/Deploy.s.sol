// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/ttcoin.sol";
import "../src/BaseERC721.sol";
import "../src/NFTMarket.sol";
import "../src/tokenbank.sol";
import "../src/SimplePermit2.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // 1. 部署 TTCoin (ERC20 with Permit)
        ttcoin token = new ttcoin(
            1000000 * 10**18,      // initialSupply (1M tokens)
            "TestToken",           // name
            "TTC"                  // symbol
        );

        // 2. 部署 BaseERC721 (NFT)
        BaseERC721 nft = new BaseERC721(
            "TestNFT",                    // name
            "TNFT",                       // symbol
            "https://api.example.com/"    // baseURI
        );

        // 3. 部署 SimplePermit2
        SimplePermit2 permit2 = new SimplePermit2();

        // 4. 部署 TokenBank
        TokenBank tokenBank = new TokenBank(token, IPermit2(address(permit2)));

        // 5. 部署 NFTMarket
        NFTMarket nftMarket = new NFTMarket(token);

        // 5. 分发测试代币给 Anvil 的测试账户
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
        }

        // 6. 为测试账户铸造一些 NFT
        for (uint i = 0; i < 3; i++) {
            nft.mintWithURI(
                testAccounts[i], 
                i + 1, 
                string(abi.encodePacked("https://api.example.com/", vm.toString(i + 1)))
            );
        }

        vm.stopBroadcast();

        // 输出部署的合约地址
        console.log("=== Contract Deployment Results ===");
        console.log("TTCoin (Token):", address(token));
        console.log("BaseERC721 (NFT):", address(nft));
        console.log("TokenBank:", address(tokenBank));
        console.log("NFTMarket:", address(nftMarket));
        console.log("Deployer:", vm.addr(deployerPrivateKey));
        console.log("=== Token Distribution ===");
        console.log("Distributed 10,000 TTC to 9 test accounts");
        console.log("Minted 3 NFTs to first 3 test accounts");
    }
}