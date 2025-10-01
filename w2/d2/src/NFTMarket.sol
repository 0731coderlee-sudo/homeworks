// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ttcoin.sol"; // 你的ERC20扩展Token
import "./BaseERC721.sol"; // 你的NFT合约
import "./interfaces.sol";

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

    event Listed(address indexed nft, uint256 indexed tokenId, address seller, uint256 price, address paymentToken);
    event Bought(address indexed nft, uint256 indexed tokenId, address buyer, uint256 price, address paymentToken);
    event TokenAdded(address indexed token);
    event TokenRemoved(address indexed token);

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
}