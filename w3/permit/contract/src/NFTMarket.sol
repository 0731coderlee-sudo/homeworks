// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ttcoin} from "./ttcoin.sol"; // 你的ERC20扩展Token
import {BaseERC721} from "./BaseERC721.sol"; // 你的NFT合约
import {IERC20, ITokenCallback, IERC20Permit} from "./interfaces.sol";

contract NFTMarket is ITokenCallback {
    struct Listing {
        address seller;
        uint256 price;
        address paymentToken;  // 支付代币地址
    }
    // nft合约地址 => tokenId => Listing
    mapping(address => mapping(uint256 => Listing)) public listings;
    ttcoin public token;  // 保留原有ttcoin用于callback
    
    // 支持的ERC20代币白名单
    mapping(address => bool) public supportedTokens;
    address public owner;
    
    // Permit 购买白名单：只有白名单用户可以使用 permitBuy 功能
    mapping(address => bool) public permitWhitelist;
    // 白名单签名的 nonce，防止重放攻击
    mapping(address => uint256) public whitelistNonces;

    event Listed(address indexed nft, uint256 indexed tokenId, address seller, uint256 price, address paymentToken);
    event Bought(address indexed nft, uint256 indexed tokenId, address buyer, uint256 price, address paymentToken);
    event PermitBought(address indexed nft, uint256 indexed tokenId, address buyer, uint256 price, address paymentToken);
    event TokenAdded(address indexed token);
    event TokenRemoved(address indexed token);
    event WhitelistAdded(address indexed user);
    event WhitelistRemoved(address indexed user);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor(ttcoin _token) {
        token = _token;
        owner = msg.sender;
        // 默认支持ttcoin
        supportedTokens[address(_token)] = true;
        emit TokenAdded(address(_token));
    }

    // 添加支持的代币
    function addSupportedToken(address tokenAddress) external onlyOwner {
        require(tokenAddress != address(0), "Invalid token address");
        supportedTokens[tokenAddress] = true;
        emit TokenAdded(tokenAddress);
    }
    
    // 移除支持的代币
    function removeSupportedToken(address tokenAddress) external onlyOwner {
        supportedTokens[tokenAddress] = false;
        emit TokenRemoved(tokenAddress);
    }

    // 上架NFT（默认使用ttcoin）
    function list(address nft, uint256 tokenId, uint256 price) external {
        _listWithToken(nft, tokenId, price, address(token));
    }
    
    // 上架NFT（指定支付代币）
    function listWithToken(address nft, uint256 tokenId, uint256 price, address paymentToken) external {
        _listWithToken(nft, tokenId, price, paymentToken);
    }
    
    // 内部上架函数
    function _listWithToken(address nft, uint256 tokenId, uint256 price, address paymentToken) internal {
        require(price > 0, "price zero");
        require(supportedTokens[paymentToken], "payment token not supported");
        BaseERC721 nftContract = BaseERC721(nft);
        require(nftContract.ownerOf(tokenId) == msg.sender, "not owner");
        // 转移NFT到市场合约
        nftContract.transferFrom(msg.sender, address(this), tokenId);
        listings[nft][tokenId] = Listing(msg.sender, price, paymentToken);
        emit Listed(nft, tokenId, msg.sender, price, paymentToken);
    }

    // 普通购买NFT
    function buyNFT(address nft, uint256 tokenId) external {
        Listing memory l = listings[nft][tokenId];
        require(l.price > 0, "not listed");
        
        // 使用指定的支付代币
        IERC20 paymentToken = IERC20(l.paymentToken);
        require(paymentToken.transferFrom(msg.sender, l.seller, l.price), "token transfer failed");
        
        // 转移NFT给买家
        BaseERC721(nft).transferFrom(address(this), msg.sender, tokenId);
        delete listings[nft][tokenId];
        emit Bought(nft, tokenId, msg.sender, l.price, l.paymentToken);
    }

    // ERC20扩展Token的钩子购买（仅支持ttcoin callback）
    // data: abi.encode(nft, tokenId)
    function tokensReceived(address from, uint256 amount, bytes calldata data) external override {
        require(msg.sender == address(token), "only ttcoin contract");
        (address nft, uint256 tokenId) = abi.decode(data, (address, uint256));
        Listing memory l = listings[nft][tokenId];
        require(l.price > 0, "not listed");
        require(l.paymentToken == address(token), "payment token mismatch");
        require(amount >= l.price, "price not enough");
        // 转移token给卖家
        require(token.transfer(l.seller, l.price), "token transfer failed");
        // 转移NFT给买家
        BaseERC721(nft).transferFrom(address(this), from, tokenId);
        delete listings[nft][tokenId];
        emit Bought(nft, tokenId, from, l.price, l.paymentToken);
    }
    
    // 获取上架信息
    function getListing(address nft, uint256 tokenId) external view returns (
        address seller,
        uint256 price,
        address paymentToken
    ) {
        Listing memory l = listings[nft][tokenId];
        return (l.seller, l.price, l.paymentToken);
    }
    
    // 检查代币是否被支持
    function isTokenSupported(address tokenAddress) external view returns (bool) {
        return supportedTokens[tokenAddress];
    }
    
    // ===== Permit 白名单购买功能 =====
    
    /// @notice 添加用户到白名单
    /// @param user 要添加的用户地址
    function addToWhitelist(address user) external onlyOwner {
        require(user != address(0), "Invalid user address");
        permitWhitelist[user] = true;
        emit WhitelistAdded(user);
    }
    
    /// @notice 从白名单中移除用户
    /// @param user 要移除的用户地址
    function removeFromWhitelist(address user) external onlyOwner {
        permitWhitelist[user] = false;
        emit WhitelistRemoved(user);
    }
    
    /// @notice 检查用户是否在白名单中
    /// @param user 要检查的用户地址
    function isWhitelisted(address user) external view returns (bool) {
        return permitWhitelist[user];
    }
    
    /// @notice 使用 Permit 签名购买 NFT（仅限白名单用户）
    /// @param nft NFT 合约地址
    /// @param tokenId NFT Token ID
    /// @param buyer 买家地址（必须在白名单中）
    /// @param deadline permit 签名过期时间
    /// @param v 签名参数 v
    /// @param r 签名参数 r
    /// @param s 签名参数 s
    function permitBuy(
        address nft,
        uint256 tokenId,
        address buyer,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        require(permitWhitelist[buyer], "Buyer not whitelisted");
        
        Listing memory l = listings[nft][tokenId];
        require(l.price > 0, "not listed");
        
        // 只支持 ttcoin 的 permit 购买
        require(l.paymentToken == address(token), "Only ttcoin permit supported");
        
        // 使用 permit 进行授权
        IERC20Permit(address(token)).permit(
            buyer,
            address(this),
            l.price,
            deadline,
            v, r, s
        );
        
        // 执行购买
        require(token.transferFrom(buyer, l.seller, l.price), "token transfer failed");
        
        // 转移NFT给买家
        BaseERC721(nft).transferFrom(address(this), buyer, tokenId);
        delete listings[nft][tokenId];
        
        emit PermitBought(nft, tokenId, buyer, l.price, l.paymentToken);
    }
    
    /// @notice 批量添加白名单用户
    /// @param users 要添加的用户地址数组
    function batchAddToWhitelist(address[] calldata users) external onlyOwner {
        for (uint256 i = 0; i < users.length; i++) {
            require(users[i] != address(0), "Invalid user address");
            permitWhitelist[users[i]] = true;
            emit WhitelistAdded(users[i]);
        }
    }
    
    /// @notice 批量移除白名单用户
    /// @param users 要移除的用户地址数组
    function batchRemoveFromWhitelist(address[] calldata users) external onlyOwner {
        for (uint256 i = 0; i < users.length; i++) {
            permitWhitelist[users[i]] = false;
            emit WhitelistRemoved(users[i]);
        }
    }
}