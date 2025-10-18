// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

/**
 * @title MerkleAirdrop
 * @notice 集成了nft市场功能的Merkle空投合约
 * @dev 通过验证的白名单用户可以使用50%的折扣购买NFT
 */
contract MerkleAirdrop is Ownable, IERC721Receiver {
    IERC20 public immutable token;
    bytes32 public immutable merkleRoot;

    mapping(address => bool) public hasClaimed;

    struct Listing {
        address seller;
        address nftContract;
        uint256 tokenId;
        uint256 price;
        bool active;
    }

    mapping(uint256 => Listing) public listings;
    uint256 public nextListingId;

    event Claimed(address indexed account, uint256 amount);
    event NFTListed(uint256 indexed listingId, address indexed seller, address indexed nftContract, uint256 tokenId, uint256 price);
    event NFTDelisted(uint256 indexed listingId);
    event NFTPurchased(uint256 indexed listingId, address indexed buyer, uint256 price, bool discounted);

    error AlreadyClaimed();
    error InvalidProof();
    error TransferFailed();
    error NotListingOwner();
    error ListingNotActive();
    error InvalidPrice();

    constructor(
        address _token,
        bytes32 _merkleRoot
    ) Ownable(msg.sender) {
        token = IERC20(_token);
        merkleRoot = _merkleRoot;
    }

    // ============ Airdrop Functions ============

    function claim(uint256 amount, bytes32[] calldata proof) external {
        if (hasClaimed[msg.sender]) {
            revert AlreadyClaimed();
        }

        // 基于 Merkle 树验证某用户是否在白名单中
        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(msg.sender, amount))));
        if (!MerkleProof.verify(proof, merkleRoot, leaf)) {
            revert InvalidProof();
        }
        hasClaimed[msg.sender] = true;
        bool success = token.transfer(msg.sender, amount);
        if (!success) {
            revert TransferFailed();
        }
        emit Claimed(msg.sender, amount);
    }

    function isClaimed(address account) external view returns (bool) {
        return hasClaimed[account];
    }

    function withdrawRemaining(address to) external onlyOwner {
        uint256 balance = token.balanceOf(address(this));
        bool success = token.transfer(to, balance);
        if (!success) {
            revert TransferFailed();
        }
    }

    // ============ NFT Market Functions ============


    function listNFT(address nftContract, uint256 tokenId, uint256 price) external returns (uint256) {
        if (price == 0) {
            revert InvalidPrice();
        }

        // Transfer NFT to this contract
        IERC721(nftContract).safeTransferFrom(msg.sender, address(this), tokenId);

        uint256 listingId = nextListingId++;
        listings[listingId] = Listing({
            seller: msg.sender,
            nftContract: nftContract,
            tokenId: tokenId,
            price: price,
            active: true
        });

        emit NFTListed(listingId, msg.sender, nftContract, tokenId, price);
        return listingId;
    }


    function delistNFT(uint256 listingId) external {
        Listing storage listing = listings[listingId];

        if (listing.seller != msg.sender) {
            revert NotListingOwner();
        }
        if (!listing.active) {
            revert ListingNotActive();
        }

        listing.active = false;

        // Return NFT to seller
        IERC721(listing.nftContract).safeTransferFrom(address(this), msg.sender, listing.tokenId);

        emit NFTDelisted(listingId);
    }

    function buyNFT(uint256 listingId) external {
        Listing storage listing = listings[listingId];

        if (!listing.active) {
            revert ListingNotActive();
        }

        listing.active = false;

        // Transfer tokens from buyer to seller
        bool success = token.transferFrom(msg.sender, listing.seller, listing.price);
        if (!success) {
            revert TransferFailed();
        }

        // Transfer NFT to buyer
        IERC721(listing.nftContract).safeTransferFrom(address(this), msg.sender, listing.tokenId);

        emit NFTPurchased(listingId, msg.sender, listing.price, false);
    }

    function getListing(uint256 listingId) external view returns (Listing memory) {
        return listings[listingId];
    }

    // ============ Multicall Functions ============

    function permitPrePay(
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public {
        IERC20Permit(address(token)).permit(
            msg.sender,
            address(this),
            amount,
            deadline,
            v,
            r,
            s
        );
    }

    function claimNFT(
        uint256 listingId,
        bytes32[] calldata proof,
        uint256 whitelistAmount
    ) public {
        Listing storage listing = listings[listingId];

        // Verify listing is active
        if (!listing.active) {
            revert ListingNotActive();
        }

        // Verify whitelist status using Merkle proof
        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(msg.sender, whitelistAmount))));
        if (!MerkleProof.verify(proof, merkleRoot, leaf)) {
            revert InvalidProof();
        }

        // Deactivate listing
        listing.active = false;

        // Calculate discounted price (50% off for whitelisted users)
        uint256 discountedPrice = listing.price / 2;

        // Transfer tokens from buyer to seller (using permit authorization)
        bool success = token.transferFrom(msg.sender, listing.seller, discountedPrice);
        if (!success) {
            revert TransferFailed();
        }

        // Transfer NFT to buyer
        IERC721(listing.nftContract).safeTransferFrom(address(this), msg.sender, listing.tokenId);

        emit NFTPurchased(listingId, msg.sender, discountedPrice, true);
    }

    /**
     * @notice Execute multiple calls in a single transaction using delegatecall
     * @dev Allows batching permitPrePay + claimNFT into one transaction
     * @param data Array of encoded function calls
     * @return results Array of return data from each call
     */
    function multicall(bytes[] calldata data) external returns (bytes[] memory results) {
        results = new bytes[](data.length);
        // 以用户的身份发起permitPrePay调用以及claimNFT调用
        for (uint256 i = 0; i < data.length; i++) {
            (bool success, bytes memory result) = address(this).delegatecall(data[i]);

            if (!success) {
                // Bubble up the revert reason
                if (result.length > 0) {
                    assembly {
                        let returndata_size := mload(result)
                        revert(add(32, result), returndata_size)
                    }
                } else {
                    revert("Multicall: delegatecall failed");
                }
            }

            results[i] = result;
        }
    }

    /**
     * @notice Required for receiving NFTs
     */
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}