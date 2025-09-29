// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ttcoin.sol"; // 你的ERC20扩展Token
import "./BaseERC721.sol"; // 你的NFT合约
import "./interfaces.sol";

contract NFTMarket is ITokenCallback {
    struct Listing {
        address seller;
        uint256 price;
    }
    // nft合约地址 => tokenId => Listing
    mapping(address => mapping(uint256 => Listing)) public listings;
    ttcoin public token;

    event Listed(address indexed nft, uint256 indexed tokenId, address seller, uint256 price);
    event Bought(address indexed nft, uint256 indexed tokenId, address buyer, uint256 price);

    constructor(ttcoin _token) {
        token = _token;
    }

    // 上架NFT
    function list(address nft, uint256 tokenId, uint256 price) external {
        require(price > 0, "price zero");
        BaseERC721 nftContract = BaseERC721(nft);
        require(nftContract.ownerOf(tokenId) == msg.sender, "not owner");
        // 转移NFT到市场合约
        nftContract.transferFrom(msg.sender, address(this), tokenId);
        listings[nft][tokenId] = Listing(msg.sender, price);
        emit Listed(nft, tokenId, msg.sender, price);
    }

    // 普通购买NFT
    function buyNFT(address nft, uint256 tokenId) external {
        Listing memory l = listings[nft][tokenId];
        require(l.price > 0, "not listed");
        // 买家先approve，再transferFrom
        require(token.transferFrom(msg.sender, l.seller, l.price), "token transfer failed");
        // 转移NFT给买家
        BaseERC721(nft).transferFrom(address(this), msg.sender, tokenId);
        delete listings[nft][tokenId];
        emit Bought(nft, tokenId, msg.sender, l.price);
    }

    // ERC20扩展Token的钩子购买
    // data: abi.encode(nft, tokenId)
    function tokensReceived(address from, uint256 amount, bytes calldata data) external override {
        require(msg.sender == address(token), "only token contract");
        (address nft, uint256 tokenId) = abi.decode(data, (address, uint256));
        Listing memory l = listings[nft][tokenId];
        require(l.price > 0, "not listed");
        require(amount >= l.price, "price not enough");
        // 转移token给卖家
        require(token.transfer(l.seller, l.price), "token transfer failed");
        // 转移NFT给买家
        BaseERC721(nft).transferFrom(address(this), from, tokenId);
        delete listings[nft][tokenId];
        emit Bought(nft, tokenId, from, l.price);
    }
}