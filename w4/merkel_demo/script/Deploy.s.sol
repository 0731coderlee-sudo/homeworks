// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/AirdropToken.sol";
import "../src/AirdropNFT.sol";
import "../src/MerkleAirdrop.sol";

/**
 * @title Deploy
 * @notice Deployment script for all airdrop contracts
 */
contract Deploy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Deploy ERC20 Token
        AirdropToken token = new AirdropToken(
            "Airdrop Token",
            "ADT",
            1_000_000 * 10**18 // 1 million tokens
        );
        console.log("AirdropToken deployed at:", address(token));

        // Deploy ERC721 NFT
        AirdropNFT nft = new AirdropNFT(
            "Airdrop NFT",
            "ANFT"
        );
        console.log("AirdropNFT deployed at:", address(nft));

        // Example merkle root (replace with actual root)
        bytes32 merkleRoot = bytes32(0);

        // Deploy MerkleAirdrop
        MerkleAirdrop airdrop = new MerkleAirdrop(
            address(token),
            merkleRoot
        );
        console.log("MerkleAirdrop deployed at:", address(airdrop));

        vm.stopBroadcast();
    }
}
