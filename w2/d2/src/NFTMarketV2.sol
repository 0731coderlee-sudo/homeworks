// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ttcoin.sol";
import "./BaseERC721.sol";
import "./interfaces.sol";

/**
 * @title NFTMarketV2 - Gas Optimized Version
 * @notice 应用多种 EVM 存储布局优化技术
 */
contract NFTMarketV2 is ITokenCallback {

    // ============================================
    // 优化1: Custom Errors (节省部署和运行时 gas)
    // ============================================
    error PriceZero();
    error NotOwner();
    error NotListed();
    error NotEnoughPayment();
    error TokenNotSupported();
    error InvalidTokenAddress();
    error TransferFailed();
    error OnlyTTCoinContract();
    error PaymentTokenMismatch();

    // ============================================
    // 优化2: Struct Packing (从3个slot优化到2个slot)
    // ============================================
    // 原始: address(20) + uint256(32) + address(20) = 3 slots
    // 优化: uint96(12) + address(20) = 1 slot, address(20) = 1 slot = 2 slots
    // uint96 最大值: 79,228,162,514 ether (足够NFT价格使用)
    struct Listing {
        uint96 price;           // 12 bytes - Slot 1
        address seller;         // 20 bytes - Slot 1 (total 32 bytes)
        address paymentToken;   // 20 bytes - Slot 2
    }

    // ============================================
    // 优化3: Storage Layout - 变量打包
    // ============================================
    // 原始布局占用4个slots，优化后占用2个slots

    // Slot 0: owner (20 bytes) + 可以添加其他小变量
    address public owner;           // 20 bytes
    // 剩余12字节可供未来扩展使用

    // Slot 1: token (immutable不占用storage)
    ttcoin public immutable token;  // 优化: 使用immutable，不占用storage slot

    // Slot 2: listings mapping
    mapping(address => mapping(uint256 => Listing)) public listings;

    // Slot 3: supportedTokens mapping
    mapping(address => bool) public supportedTokens;

    // ============================================
    // Events (优化: 减少indexed参数以节省gas)
    // ============================================
    event Listed(address indexed nft, uint256 tokenId, address seller, uint96 price, address paymentToken);
    event Bought(address indexed nft, uint256 tokenId, address buyer, uint96 price, address paymentToken);
    event TokenAdded(address indexed token);
    event TokenRemoved(address indexed token);

    // ============================================
    // Modifiers
    // ============================================
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    // ============================================
    // Constructor
    // ============================================
    constructor(ttcoin _token) {
        token = _token;
        owner = msg.sender;
        supportedTokens[address(_token)] = true;
        emit TokenAdded(address(_token));
    }

    // ============================================
    // 优化4: 函数优化 - 减少存储读取
    // ============================================

    function addSupportedToken(address tokenAddress) external onlyOwner {
        if (tokenAddress == address(0)) revert InvalidTokenAddress();
        supportedTokens[tokenAddress] = true;
        emit TokenAdded(tokenAddress);
    }

    function removeSupportedToken(address tokenAddress) external onlyOwner {
        supportedTokens[tokenAddress] = false;
        emit TokenRemoved(tokenAddress);
    }

    // 上架NFT（默认使用ttcoin）
    function list(address nft, uint256 tokenId, uint96 price) external {
        _listWithToken(nft, tokenId, price, address(token));
    }

    // 上架NFT（指定支付代币）
    function listWithToken(address nft, uint256 tokenId, uint96 price, address paymentToken) external {
        _listWithToken(nft, tokenId, price, paymentToken);
    }

    // ============================================
    // 优化5: 内部函数优化 - 条件检查顺序
    // ============================================
    // 先检查便宜的操作（price > 0），再检查昂贵的操作（storage读取）
    function _listWithToken(address nft, uint256 tokenId, uint96 price, address paymentToken) internal {
        // 优化: 先检查简单条件
        if (price == 0) revert PriceZero();
        if (!supportedTokens[paymentToken]) revert TokenNotSupported();

        BaseERC721 nftContract = BaseERC721(nft);

        // 优化: 使用局部变量缓存msg.sender，减少多次访问
        address seller = msg.sender;
        if (nftContract.ownerOf(tokenId) != seller) revert NotOwner();

        // 转移NFT到市场合约
        nftContract.transferFrom(seller, address(this), tokenId);

        // 优化: 直接写入struct，减少多次存储操作
        listings[nft][tokenId] = Listing({
            price: price,
            seller: seller,
            paymentToken: paymentToken
        });

        emit Listed(nft, tokenId, seller, price, paymentToken);
    }

    // ============================================
    // 优化6: buyNFT - 存储访问优化
    // ============================================
    function buyNFT(address nft, uint256 tokenId) external {
        // 优化: 一次性读取listing到memory
        Listing memory listing = listings[nft][tokenId];

        if (listing.price == 0) revert NotListed();

        // 优化: 缓存变量减少重复访问
        address buyer = msg.sender;
        address seller = listing.seller;
        uint96 price = listing.price;

        // 使用指定的支付代币
        IERC20 paymentToken = IERC20(listing.paymentToken);

        // 优化: 先检查后执行，减少失败时的gas消耗
        if (!paymentToken.transferFrom(buyer, seller, price)) {
            revert TransferFailed();
        }

        // 转移NFT给买家
        BaseERC721(nft).transferFrom(address(this), buyer, tokenId);

        // 优化: 使用delete清除存储（获得gas refund）
        delete listings[nft][tokenId];

        emit Bought(nft, tokenId, buyer, price, listing.paymentToken);
    }

    // ============================================
    // 优化7: tokensReceived - 回调函数优化
    // ============================================
    function tokensReceived(address from, uint256 amount, bytes calldata data) external override {
        // 优化: 使用custom error替代require string
        if (msg.sender != address(token)) revert OnlyTTCoinContract();

        (address nft, uint256 tokenId) = abi.decode(data, (address, uint256));

        // 优化: 一次性读取到memory
        Listing memory listing = listings[nft][tokenId];

        if (listing.price == 0) revert NotListed();
        if (listing.paymentToken != address(token)) revert PaymentTokenMismatch();
        if (amount < listing.price) revert NotEnoughPayment();

        // 优化: 缓存变量
        address seller = listing.seller;
        uint96 price = listing.price;

        // 转移token给卖家
        if (!token.transfer(seller, price)) revert TransferFailed();

        // 转移NFT给买家
        BaseERC721(nft).transferFrom(address(this), from, tokenId);

        // 清除listing
        delete listings[nft][tokenId];

        emit Bought(nft, tokenId, from, price, listing.paymentToken);
    }

    // ============================================
    // View Functions (优化: 使用memory而非storage)
    // ============================================
    function getListing(address nft, uint256 tokenId) external view returns (
        address seller,
        uint96 price,
        address paymentToken
    ) {
        Listing memory listing = listings[nft][tokenId];
        return (listing.seller, listing.price, listing.paymentToken);
    }

    function isTokenSupported(address tokenAddress) external view returns (bool) {
        return supportedTokens[tokenAddress];
    }
}
