// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// NFT 市场合约 V2 - 可升级版本（简化实现）
// 功能：NFT 上架、购买、取消，支持多种 ERC20 代币支付
// 安全特性：防重入、可暂停、权限控制、安全的代币转账
//
// 升级支持说明：
// 1. 本合约设计为可通过代理模式部署和升级
// 2. 不使用 constructor，改用 initialize 函数
// 3. 不使用 immutable 变量
// 4. 预留存储空间 (__gap) 供未来版本扩展
contract NFTMarketV2Upgradeable {
    using SafeERC20 for IERC20;

    // ============================================
    // 自定义错误（节省 gas）
    // ============================================
    error PriceZero();                  // 价格不能为 0
    error NotNFTOwner();                // 不是 NFT 拥有者
    error NotListed();                  // NFT 未上架
    error TokenNotSupported();          // 不支持的支付代币
    error InvalidTokenAddress();        // 无效的代币地址
    error AlreadyInitialized();         // 已经初始化
    error NotOwner();                   // 不是所有者
    error Paused();                     // 合约已暂停
    error ReentrancyDetected();         // 检测到重入

    // ============================================
    // 数据结构（优化存储布局）
    // ============================================
    struct Listing {
        uint96 price;           // 12 字节 - Slot 1
        address seller;         // 20 字节 - Slot 1（共 32 字节）
        address paymentToken;   // 20 字节 - Slot 2
    }

    // ============================================
    // 状态变量
    // ============================================
    // 注意：可升级合约不能使用 immutable 或 constructor

    // 初始化标志
    bool private _initialized;

    // 重入锁
    uint256 private _status;
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    // 暂停标志
    bool private _paused;

    // 所有者
    address public owner;

    // NFT 上架信息
    mapping(address => mapping(uint256 => Listing)) public listings;

    // 支持的支付代币白名单
    mapping(address => bool) public supportedTokens;

    // ============================================
    // 存储间隙（Storage Gap）
    // ============================================
    // 预留 50 个存储槽位，供未来版本扩展使用
    uint256[50] private __gap;

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
    event ListingCancelled(address indexed nft, uint256 indexed tokenId);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    // ============================================
    // 修饰符
    // ============================================

    // 防重入修饰符
    modifier nonReentrant() {
        if (_status == _ENTERED) revert ReentrancyDetected();
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }

    // 未暂停修饰符
    modifier whenNotPaused() {
        if (_paused) revert Paused();
        _;
    }

    // 仅所有者修饰符
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    // ============================================
    // 初始化函数（替代 constructor）
    // ============================================

    // 初始化函数 - 只能调用一次
    // 注意：部署代理合约后必须立即调用此函数
    function initialize() public {
        if (_initialized) revert AlreadyInitialized();

        _initialized = true;
        _status = _NOT_ENTERED;
        _paused = false;
        owner = msg.sender;

        emit OwnershipTransferred(address(0), msg.sender);
    }

    // ============================================
    // 升级授权（UUPS 模式）
    // ============================================

    // ERC1967 实现槽位
    bytes32 private constant _IMPLEMENTATION_SLOT =
        0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    // 升级事件
    event Upgraded(address indexed implementation);

    // 升级到新实现（仅所有者可调用）
    function upgradeTo(address newImplementation) external onlyOwner {
        require(newImplementation != address(0), "Invalid implementation");

        // 通过 delegatecall 修改代理的实现地址
        assembly {
            sstore(_IMPLEMENTATION_SLOT, newImplementation)
        }

        emit Upgraded(newImplementation);
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
        _paused = true;
    }

    // 恢复市场
    function unpause() external onlyOwner {
        _paused = false;
    }

    // 转移所有权
    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert InvalidTokenAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
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
        IERC20 paymentToken = IERC20(listing.paymentToken);

        // 先删除上架记录（防重入 + gas 退款）
        delete listings[nft][tokenId];

        // 使用 SafeERC20 安全转账代币给卖家
        paymentToken.safeTransferFrom(buyer, seller, price);

        // 转移 NFT 给买家
        IERC721(nft).transferFrom(address(this), buyer, tokenId);

        emit Bought(nft, tokenId, buyer, price, address(paymentToken));
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

        emit ListingCancelled(nft, tokenId);
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

    // 检查是否已暂停
    function paused() external view returns (bool) {
        return _paused;
    }

    // 获取当前合约版本
    function version() external pure returns (string memory) {
        return "2.0.0";
    }
}
