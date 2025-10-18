// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// BaseERC721 - 基础 NFT 合约
// 功能：铸造、销毁、URI 管理、批量操作
// 使用 OpenZeppelin 标准库确保安全性和兼容性
contract BaseERC721 is ERC721, ERC721URIStorage, ERC721Burnable, Ownable {

    // 自增 Token ID 计数器
    uint256 private _currentTokenId;

    // 所有代币的基础 URI
    string private _baseTokenURI;

    // ============================================
    // 构造函数
    // ============================================
    // name_: 代币名称
    // symbol_: 代币符号
    // baseURI_: 基础 URI
    constructor(
        string memory name_,
        string memory symbol_,
        string memory baseURI_
    ) ERC721(name_, symbol_) Ownable(msg.sender) {
        _baseTokenURI = baseURI_;
    }

    // ============================================
    // 基础 URI 管理
    // ============================================

    // 返回基础 URI（内部函数，被 tokenURI 使用）
    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }

    // 设置新的基础 URI（仅所有者）
    function setBaseURI(string memory newBaseURI) public onlyOwner {
        _baseTokenURI = newBaseURI;
    }

    // 获取当前基础 URI
    function baseURI() public view returns (string memory) {
        return _baseTokenURI;
    }

    // ============================================
    // 铸造功能
    // ============================================

    // 铸造指定 ID 的 NFT
    // to: 接收地址
    // tokenId: 代币 ID
    function mint(address to, uint256 tokenId) public onlyOwner {
        _safeMint(to, tokenId);
    }

    // 铸造 NFT 并设置自定义 URI
    // to: 接收地址
    // tokenId: 代币 ID
    // customURI: 自定义 URI
    function mintWithURI(address to, uint256 tokenId, string memory customURI) public onlyOwner {
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, customURI);
    }

    // 自动递增铸造（带自定义 URI）
    // to: 接收地址
    // customURI: 自定义 URI
    // 返回: 铸造的 Token ID
    function autoMintWithURI(address to, string memory customURI) public onlyOwner returns (uint256) {
        _currentTokenId++;
        uint256 tokenId = _currentTokenId;

        _safeMint(to, tokenId);
        _setTokenURI(tokenId, customURI);

        return tokenId;
    }

    // ============================================
    // 批量铸造功能
    // ============================================

    // 批量铸造多个 NFT
    // to: 接收地址
    // tokenIds: Token ID 数组
    function batchMint(address to, uint256[] calldata tokenIds) external onlyOwner {
        for (uint256 i = 0; i < tokenIds.length; i++) {
            _safeMint(to, tokenIds[i]);
        }
    }

    // 批量铸造并设置自定义 URI
    // to: 接收地址
    // tokenIds: Token ID 数组
    // customURIs: 自定义 URI 数组
    function batchMintWithURIs(
        address to,
        uint256[] calldata tokenIds,
        string[] calldata customURIs
    ) external onlyOwner {
        require(tokenIds.length == customURIs.length, "BaseERC721: arrays length mismatch");

        for (uint256 i = 0; i < tokenIds.length; i++) {
            _safeMint(to, tokenIds[i]);
            _setTokenURI(tokenIds[i], customURIs[i]);
        }
    }

    // ============================================
    // URI 管理
    // ============================================

    // 为已存在的 Token 设置自定义 URI
    // tokenId: Token ID
    // customURI: 新的 URI
    function setTokenURI(uint256 tokenId, string memory customURI) public onlyOwner {
        _setTokenURI(tokenId, customURI);
    }

    // 获取 Token 的自定义 URI（别名函数）
    // tokenId: Token ID
    function getCustomTokenURI(uint256 tokenId) public view returns (string memory) {
        return tokenURI(tokenId);
    }

    // ============================================
    // 必需的重写函数
    // ============================================

    // 重写 tokenURI 函数（ERC721 和 ERC721URIStorage 都需要）
    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    // 重写 supportsInterface 函数
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}

// BaseERC721Receiver - 简单的 ERC721 接收器
// 用于测试或其他需要接收 NFT 的合约
contract BaseERC721Receiver is IERC721Receiver {
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
