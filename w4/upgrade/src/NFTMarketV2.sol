// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

// NFT 市场合约 V2 - 安全且 Gas 优化版本
// 功能：NFT 上架、购买，支持多种 ERC20 代币支付
// 安全特性：防重入、可暂停、权限控制、安全的代币转账
contract NFTMarketV2 is ReentrancyGuard, Ownable, Pausable {
    using SafeERC20 for IERC20;

    // ============================================
    // 自定义错误（节省 gas）
    // ============================================
    error PriceZero();                  // 价格不能为 0
    error NotNFTOwner();                // 不是 NFT 拥有者
    error NotListed();                  // NFT 未上架
    error TokenNotSupported();          // 不支持的支付代币
    error InvalidTokenAddress();        // 无效的代币地址

    // ============================================
    // 数据结构（优化存储布局）
    // ============================================
    // Listing 结构体：2 个 slot 而不是 3 个
    struct Listing {
        uint96 price;           // 12 字节 - Slot 1
        address seller;         // 20 字节 - Slot 1（共 32 字节）
        address paymentToken;   // 20 字节 - Slot 2
    }

    // ============================================
    // 状态变量
    // ============================================
    // NFT 上架信息：NFT 合约地址 => Token ID => 上架详情
    mapping(address => mapping(uint256 => Listing)) public listings;

    // 支持的支付代币白名单
    mapping(address => bool) public supportedTokens;

    // ============================================
    // 事件
    // ============================================
    event Listed(
        address indexed nft,
        uint256 indexed tokenId,
        address seller,
        uint96 price,
        address paymentToken
    );

    event Bought(
        address indexed nft,
        uint256 indexed tokenId,
        address buyer,
        uint96 price,
        address paymentToken
    );

    event TokenAdded(address indexed token);
    event TokenRemoved(address indexed token);

    // ============================================
    // 构造函数
    // ============================================
    constructor() Ownable(msg.sender) {
        // 可以在部署后添加支持的代币
    }

    // ============================================
    // 管理员功能
    // ============================================

    // 添加支持的支付代币
    function addSupportedToken(address tokenAddress) external onlyOwner {
        if (tokenAddress == address(0)) revert InvalidTokenAddress();
        supportedTokens[tokenAddress] = true;
        emit TokenAdded(tokenAddress);
    }

    // 移除支持的支付代币
    function removeSupportedToken(address tokenAddress) external onlyOwner {
        supportedTokens[tokenAddress] = false;
        emit TokenRemoved(tokenAddress);
    }

    // 暂停市场（紧急情况使用）
    function pause() external onlyOwner {
        _pause();
    }

    // 恢复市场
    function unpause() external onlyOwner {
        _unpause();
    }

    // ============================================
    // 上架功能
    // ============================================

    // 上架 NFT
    // nft: NFT 合约地址
    // tokenId: NFT Token ID
    // price: 价格
    // paymentToken: 支付代币地址
    function list(
        address nft,
        uint256 tokenId,
        uint96 price,
        address paymentToken
    ) external whenNotPaused {
        // 检查价格
        if (price == 0) revert PriceZero();

        // 检查支付代币是否支持
        if (!supportedTokens[paymentToken]) revert TokenNotSupported();

        // 检查是否是 NFT 拥有者
        IERC721 nftContract = IERC721(nft);
        if (nftContract.ownerOf(tokenId) != msg.sender) revert NotNFTOwner();

        // 将 NFT 转入市场合约托管
        nftContract.transferFrom(msg.sender, address(this), tokenId);

        // 创建上架记录
        listings[nft][tokenId] = Listing({
            price: price,
            seller: msg.sender,
            paymentToken: paymentToken
        });

        emit Listed(nft, tokenId, msg.sender, price, paymentToken);
    }

    // ============================================
    // 购买功能
    // ============================================

    // 购买 NFT
    // nft: NFT 合约地址
    // tokenId: NFT Token ID
    function buyNFT(
        address nft,
        uint256 tokenId
    ) external nonReentrant whenNotPaused {
        // 读取上架信息到内存（节省 gas）
        Listing memory listing = listings[nft][tokenId];

        // 检查是否已上架
        if (listing.price == 0) revert NotListed();

        // 缓存变量（节省 gas）
        address buyer = msg.sender;
        address seller = listing.seller;
        uint96 price = listing.price;
        address paymentToken = listing.paymentToken;

        // 先删除上架记录（防重入 + gas 退款）
        delete listings[nft][tokenId];

        // 使用 SafeERC20 安全转账代币给卖家
        IERC20(paymentToken).safeTransferFrom(buyer, seller, price);

        // 转移 NFT 给买家
        IERC721(nft).transferFrom(address(this), buyer, tokenId);

        emit Bought(nft, tokenId, buyer, price, paymentToken);
    }

    // 取消上架
    // nft: NFT 合约地址
    // tokenId: NFT Token ID
    function cancelListing(
        address nft,
        uint256 tokenId
    ) external whenNotPaused {
        Listing memory listing = listings[nft][tokenId];

        // 检查是否已上架
        if (listing.price == 0) revert NotListed();

        // 只有卖家可以取消
        if (listing.seller != msg.sender) revert NotNFTOwner();

        // 删除上架记录
        delete listings[nft][tokenId];

        // 将 NFT 退还给卖家
        IERC721(nft).transferFrom(address(this), msg.sender, tokenId);
    }

    // ============================================
    // 查询功能
    // ============================================

    // 获取上架详情
    function getListing(
        address nft,
        uint256 tokenId
    ) external view returns (
        address seller,
        uint96 price,
        address paymentToken
    ) {
        Listing memory listing = listings[nft][tokenId];
        return (listing.seller, listing.price, listing.paymentToken);
    }

    // 检查代币是否支持
    function isTokenSupported(address tokenAddress) external view returns (bool) {
        return supportedTokens[tokenAddress];
    }
}
