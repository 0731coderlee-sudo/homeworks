// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/MerkleAirdrop.sol";
import "../src/AirdropToken.sol";
import "../src/AirdropNFT.sol";

contract NFTMarketTest is Test {
    MerkleAirdrop public airdrop;
    AirdropToken public token;
    AirdropNFT public nft;

    address public owner;
    address public seller;
    address public buyer;
    address public whitelistedBuyer;

    uint256 constant TOTAL_SUPPLY = 10_000_000 * 10**18;
    uint256 constant NFT_PRICE = 1000 ether;

    bytes32 public merkleRoot;

    // Amounts for whitelist
    uint256 constant AMOUNT_WHITELISTED = 2000 ether;

    function setUp() public {
        owner = address(this);
        seller = address(0x1);
        buyer = address(0x2);
        whitelistedBuyer = address(0x3);

        // Deploy token with Permit support
        token = new AirdropToken("Airdrop Token", "ADT", TOTAL_SUPPLY);

        // Deploy NFT
        nft = new AirdropNFT("Airdrop NFT", "ANFT");

        // Calculate merkle tree for whitelistedBuyer
        bytes32 leaf1 = keccak256(bytes.concat(keccak256(abi.encode(whitelistedBuyer, AMOUNT_WHITELISTED))));
        bytes32 leaf2 = keccak256(bytes.concat(keccak256(abi.encode(address(0), 0))));

        merkleRoot = leaf1 < leaf2 ?
            keccak256(abi.encodePacked(leaf1, leaf2)) :
            keccak256(abi.encodePacked(leaf2, leaf1));

        // Deploy airdrop/marketplace contract
        airdrop = new MerkleAirdrop(address(token), merkleRoot);

        // Setup: Give tokens to buyers
        token.transfer(buyer, 5000 ether);
        token.transfer(whitelistedBuyer, 5000 ether);

        // Mint NFT to seller
        vm.prank(owner);
        nft.mint(seller, "ipfs://test1");
    }

    function test_ListNFT() public {
        // Seller approves and lists NFT
        vm.startPrank(seller);
        nft.approve(address(airdrop), 0);

        vm.expectEmit(true, true, true, true);
        emit MerkleAirdrop.NFTListed(0, seller, address(nft), 0, NFT_PRICE);
        uint256 listingId = airdrop.listNFT(address(nft), 0, NFT_PRICE);
        vm.stopPrank();

        assertEq(listingId, 0);
        assertEq(nft.ownerOf(0), address(airdrop));

        MerkleAirdrop.Listing memory listing = airdrop.getListing(listingId);
        assertEq(listing.seller, seller);
        assertEq(listing.nftContract, address(nft));
        assertEq(listing.tokenId, 0);
        assertEq(listing.price, NFT_PRICE);
        assertTrue(listing.active);
    }

    function test_DelistNFT() public {
        // List NFT
        vm.startPrank(seller);
        nft.approve(address(airdrop), 0);
        uint256 listingId = airdrop.listNFT(address(nft), 0, NFT_PRICE);

        // Delist NFT
        vm.expectEmit(true, false, false, false);
        emit MerkleAirdrop.NFTDelisted(listingId);
        airdrop.delistNFT(listingId);
        vm.stopPrank();

        assertEq(nft.ownerOf(0), seller);

        MerkleAirdrop.Listing memory listing = airdrop.getListing(listingId);
        assertFalse(listing.active);
    }

    function test_BuyNFT_FullPrice() public {
        // Seller lists NFT
        vm.startPrank(seller);
        nft.approve(address(airdrop), 0);
        uint256 listingId = airdrop.listNFT(address(nft), 0, NFT_PRICE);
        vm.stopPrank();

        uint256 sellerBalanceBefore = token.balanceOf(seller);
        uint256 buyerBalanceBefore = token.balanceOf(buyer);

        // Buyer purchases NFT at full price
        vm.startPrank(buyer);
        token.approve(address(airdrop), NFT_PRICE);

        vm.expectEmit(true, true, false, true);
        emit MerkleAirdrop.NFTPurchased(listingId, buyer, NFT_PRICE, false);
        airdrop.buyNFT(listingId);
        vm.stopPrank();

        // Verify transfer
        assertEq(nft.ownerOf(0), buyer);
        assertEq(token.balanceOf(seller), sellerBalanceBefore + NFT_PRICE);
        assertEq(token.balanceOf(buyer), buyerBalanceBefore - NFT_PRICE);

        MerkleAirdrop.Listing memory listing = airdrop.getListing(listingId);
        assertFalse(listing.active);
    }

    function test_RevertListNFT_ZeroPrice() public {
        vm.startPrank(seller);
        nft.approve(address(airdrop), 0);

        vm.expectRevert(MerkleAirdrop.InvalidPrice.selector);
        airdrop.listNFT(address(nft), 0, 0);
        vm.stopPrank();
    }

    function test_RevertDelistNFT_NotOwner() public {
        // Seller lists NFT
        vm.startPrank(seller);
        nft.approve(address(airdrop), 0);
        uint256 listingId = airdrop.listNFT(address(nft), 0, NFT_PRICE);
        vm.stopPrank();

        // Buyer tries to delist
        vm.prank(buyer);
        vm.expectRevert(MerkleAirdrop.NotListingOwner.selector);
        airdrop.delistNFT(listingId);
    }

    function test_RevertBuyNFT_NotActive() public {
        // Seller lists NFT
        vm.startPrank(seller);
        nft.approve(address(airdrop), 0);
        uint256 listingId = airdrop.listNFT(address(nft), 0, NFT_PRICE);

        // Delist it
        airdrop.delistNFT(listingId);
        vm.stopPrank();

        // Try to buy delisted NFT
        vm.startPrank(buyer);
        token.approve(address(airdrop), NFT_PRICE);

        vm.expectRevert(MerkleAirdrop.ListingNotActive.selector);
        airdrop.buyNFT(listingId);
        vm.stopPrank();
    }

    // ============ Multicall Tests ============

    function test_Multicall_PermitAndClaim() public {
        // Setup whitelisted buyer with private key
        uint256 whitelistedPrivateKey = 0xD0D;
        address whitelistedAddr = vm.addr(whitelistedPrivateKey);

        // Update merkle tree for this address
        bytes32 leaf1 = keccak256(bytes.concat(keccak256(abi.encode(whitelistedAddr, AMOUNT_WHITELISTED))));
        bytes32 leaf2 = keccak256(bytes.concat(keccak256(abi.encode(address(0), 0))));

        bytes32 newRoot = leaf1 < leaf2 ?
            keccak256(abi.encodePacked(leaf1, leaf2)) :
            keccak256(abi.encodePacked(leaf2, leaf1));

        // Deploy new airdrop with updated root
        airdrop = new MerkleAirdrop(address(token), newRoot);

        // Give tokens to whitelisted buyer
        token.transfer(whitelistedAddr, NFT_PRICE);

        // Seller lists NFT
        vm.startPrank(seller);
        nft.approve(address(airdrop), 0);
        uint256 listingId = airdrop.listNFT(address(nft), 0, NFT_PRICE);
        vm.stopPrank();

        // Generate proof
        bytes32[] memory proof = new bytes32[](1);
        proof[0] = leaf2;

        uint256 expectedPrice = NFT_PRICE / 2;
        uint256 deadline = block.timestamp + 1 hours;

        // Generate permit signature
        bytes32 permitHash = keccak256(
            abi.encodePacked(
                "\x19\x01",
                token.DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                        whitelistedAddr,
                        address(airdrop),
                        expectedPrice,
                        token.nonces(whitelistedAddr),
                        deadline
                    )
                )
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(whitelistedPrivateKey, permitHash);

        // Prepare multicall data
        bytes[] memory calls = new bytes[](2);

        // Call 1: permitPrePay
        calls[0] = abi.encodeWithSignature(
            "permitPrePay(uint256,uint256,uint8,bytes32,bytes32)",
            expectedPrice,
            deadline,
            v,
            r,
            s
        );

        // Call 2: claimNFT
        calls[1] = abi.encodeWithSignature(
            "claimNFT(uint256,bytes32[],uint256)",
            listingId,
            proof,
            AMOUNT_WHITELISTED
        );

        uint256 sellerBalanceBefore = token.balanceOf(seller);

        // Execute multicall
        vm.prank(whitelistedAddr);
        airdrop.multicall(calls);

        // Verify purchase completed successfully
        assertEq(nft.ownerOf(0), whitelistedAddr);
        assertEq(token.balanceOf(seller), sellerBalanceBefore + expectedPrice);
        assertEq(token.balanceOf(whitelistedAddr), NFT_PRICE - expectedPrice);

        MerkleAirdrop.Listing memory listing = airdrop.getListing(listingId);
        assertFalse(listing.active);
    }

    function test_Multicall_ClaimOnly() public {
        // Seller lists NFT
        vm.startPrank(seller);
        nft.approve(address(airdrop), 0);
        uint256 listingId = airdrop.listNFT(address(nft), 0, NFT_PRICE);
        vm.stopPrank();

        // Generate proof for whitelisted buyer
        bytes32 leaf1 = keccak256(bytes.concat(keccak256(abi.encode(whitelistedBuyer, AMOUNT_WHITELISTED))));
        bytes32 leaf2 = keccak256(bytes.concat(keccak256(abi.encode(address(0), 0))));

        bytes32[] memory proof = new bytes32[](1);
        proof[0] = leaf2;

        uint256 expectedPrice = NFT_PRICE / 2;

        // Approve manually first
        vm.prank(whitelistedBuyer);
        token.approve(address(airdrop), expectedPrice);

        // Prepare multicall with only claimNFT
        bytes[] memory calls = new bytes[](1);
        calls[0] = abi.encodeWithSignature(
            "claimNFT(uint256,bytes32[],uint256)",
            listingId,
            proof,
            AMOUNT_WHITELISTED
        );

        uint256 sellerBalanceBefore = token.balanceOf(seller);
        uint256 buyerBalanceBefore = token.balanceOf(whitelistedBuyer);

        // Execute multicall with single call
        vm.prank(whitelistedBuyer);
        airdrop.multicall(calls);

        // Verify purchase
        assertEq(nft.ownerOf(0), whitelistedBuyer);
        assertEq(token.balanceOf(seller), sellerBalanceBefore + expectedPrice);
        assertEq(token.balanceOf(whitelistedBuyer), buyerBalanceBefore - expectedPrice);
    }

    function test_Multicall_RevertOnInvalidProof() public {
        // Seller lists NFT
        vm.startPrank(seller);
        nft.approve(address(airdrop), 0);
        uint256 listingId = airdrop.listNFT(address(nft), 0, NFT_PRICE);
        vm.stopPrank();

        // Invalid proof
        bytes32[] memory invalidProof = new bytes32[](1);
        invalidProof[0] = bytes32(uint256(999));

        uint256 expectedPrice = NFT_PRICE / 2;
        uint256 deadline = block.timestamp + 1 hours;

        // Generate permit signature
        uint256 buyerPrivateKey = 0xE0E;
        address buyerAddr = vm.addr(buyerPrivateKey);
        token.transfer(buyerAddr, NFT_PRICE);

        bytes32 permitHash = keccak256(
            abi.encodePacked(
                "\x19\x01",
                token.DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                        buyerAddr,
                        address(airdrop),
                        expectedPrice,
                        token.nonces(buyerAddr),
                        deadline
                    )
                )
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(buyerPrivateKey, permitHash);

        // Prepare multicall data with invalid proof
        bytes[] memory calls = new bytes[](2);

        calls[0] = abi.encodeWithSignature(
            "permitPrePay(uint256,uint256,uint8,bytes32,bytes32)",
            expectedPrice,
            deadline,
            v,
            r,
            s
        );

        calls[1] = abi.encodeWithSignature(
            "claimNFT(uint256,bytes32[],uint256)",
            listingId,
            invalidProof,
            AMOUNT_WHITELISTED
        );

        // Should revert with InvalidProof
        vm.prank(buyerAddr);
        vm.expectRevert(MerkleAirdrop.InvalidProof.selector);
        airdrop.multicall(calls);
    }

    function test_PermitPrePay_Standalone() public {
        uint256 buyerPrivateKey = 0xF0F;
        address buyerAddr = vm.addr(buyerPrivateKey);
        token.transfer(buyerAddr, NFT_PRICE);

        uint256 amount = 500 ether;
        uint256 deadline = block.timestamp + 1 hours;

        // Generate permit signature
        bytes32 permitHash = keccak256(
            abi.encodePacked(
                "\x19\x01",
                token.DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                        buyerAddr,
                        address(airdrop),
                        amount,
                        token.nonces(buyerAddr),
                        deadline
                    )
                )
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(buyerPrivateKey, permitHash);

        // Call permitPrePay standalone
        vm.prank(buyerAddr);
        airdrop.permitPrePay(amount, deadline, v, r, s);

        // Verify allowance was set
        assertEq(token.allowance(buyerAddr, address(airdrop)), amount);
    }

    function test_ClaimNFT_Standalone() public {
        // Seller lists NFT
        vm.startPrank(seller);
        nft.approve(address(airdrop), 0);
        uint256 listingId = airdrop.listNFT(address(nft), 0, NFT_PRICE);
        vm.stopPrank();

        // Generate proof for whitelisted buyer
        bytes32 leaf1 = keccak256(bytes.concat(keccak256(abi.encode(whitelistedBuyer, AMOUNT_WHITELISTED))));
        bytes32 leaf2 = keccak256(bytes.concat(keccak256(abi.encode(address(0), 0))));

        bytes32[] memory proof = new bytes32[](1);
        proof[0] = leaf2;

        uint256 expectedPrice = NFT_PRICE / 2;

        // Approve manually first
        vm.startPrank(whitelistedBuyer);
        token.approve(address(airdrop), expectedPrice);

        uint256 sellerBalanceBefore = token.balanceOf(seller);

        // Call claimNFT standalone
        vm.expectEmit(true, true, false, true);
        emit MerkleAirdrop.NFTPurchased(listingId, whitelistedBuyer, expectedPrice, true);
        airdrop.claimNFT(listingId, proof, AMOUNT_WHITELISTED);
        vm.stopPrank();

        // Verify purchase
        assertEq(nft.ownerOf(0), whitelistedBuyer);
        assertEq(token.balanceOf(seller), sellerBalanceBefore + expectedPrice);
    }
}
