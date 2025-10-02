// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "openzeppelin-contracts/contracts/utils/Address.sol";
import "openzeppelin-contracts/contracts/utils/Strings.sol";
import "openzeppelin-contracts/contracts/token/ERC721/IERC721Receiver.sol";
import "openzeppelin-contracts/contracts/utils/Context.sol";

contract BaseERC721 {
    using Strings for uint256;
    using Address for address;
    
    address public owner;
    string private _name;
    string private _symbol;
    string private _baseURI;
    // Mapping from token ID to owner address
    mapping(uint256 => address) private _owners;
    // Mapping owner address to token count
    mapping(address => uint256) private _balances;
    // Mapping from token ID to approved address
    mapping(uint256 => address) private _tokenApprovals;
    // Mapping from owner to operator approvals
    mapping(address => mapping(address => bool)) private _operatorApprovals;
    // Mapping from token ID to custom tokenURI (overrides baseURI + tokenId)
    mapping(uint256 => string) private _customTokenURIs;

    event Transfer(
        address indexed from,
        address indexed to,
        uint256 indexed tokenId
    );

    event Approval(
        address indexed owner,
        address indexed approved,
        uint256 indexed tokenId
    );

    event ApprovalForAll(
        address indexed owner,
        address indexed operator,
        bool approved
    );

    event OwnershipTransferred(
        address indexed previousOwner, 
        address indexed newOwner
    );

    modifier onlyOwner() {
        require(msg.sender == owner, "BaseERC721: caller is not the owner");
        _;
    }

    constructor(
        string memory name_,
        string memory symbol_,
        string memory baseURI_
    ) {
        /**code*/
        _name = name_;
        _symbol = symbol_;
        _baseURI = baseURI_;
        owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public pure returns (bool) {
        return
            interfaceId == 0x01ffc9a7 || // ERC165 Interface ID for ERC165 supportsInterface(bytes4)
            interfaceId == 0x80ac58cd || // ERC165 Interface ID for ERC721
            interfaceId == 0x5b5e139f;   // ERC165 Interface ID for ERC721Metadata
    }
    
    /**
     * @dev See {IERC721Metadata-name}.
     */
    function name() public view returns (string memory) {
        /**code*/
        return _name;
    }

    /**
     * @dev See {IERC721Metadata-symbol}.
     */
    function symbol() public view returns (string memory) {
        /**code*/
        return _symbol;
    }

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 tokenId) public view returns (string memory) {
        // should return baseURI
        /**code*/
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");
        
        // 如果设置了自定义URI，优先使用自定义URI
        string memory customURI = _customTokenURIs[tokenId];
        if (bytes(customURI).length > 0) {
            return customURI;
        }
        
        // 否则使用默认的 baseURI + tokenId
        return string(abi.encodePacked(_baseURI, tokenId.toString()));
    }

    /**
     * @dev Mints `tokenId` and transfers it to `to`.
     *
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - `tokenId` must not exist.
     *
     * Emits a {Transfer} event.
     */
    function mint(address to, uint256 tokenId) public onlyOwner {
        /**code*/
        require(to != address(0), "ERC721: mint to the zero address");
        require(!_exists(tokenId), "ERC721: token already minted");
        _owners[tokenId] = to;
        _balances[to] += 1;

        emit Transfer(address(0), to, tokenId);
    }

    /**
     * @dev Batch mint multiple tokens to the same address
     */
    function batchMint(address to, uint256[] calldata tokenIds) external onlyOwner {
        require(to != address(0), "ERC721: mint to the zero address");
        
        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];
            require(!_exists(tokenId), "ERC721: token already minted");
            _owners[tokenId] = to;
        }
        
        _balances[to] += tokenIds.length;
        
        for (uint256 i = 0; i < tokenIds.length; i++) {
            emit Transfer(address(0), to, tokenIds[i]);
        }
    }

    /**
     * @dev Mint token with custom tokenURI
     * @param to Address to mint the token to
     * @param tokenId Token ID to mint
     * @param customURI Custom URI for this specific token
     */
    function mintWithURI(address to, uint256 tokenId, string memory customURI) public onlyOwner {
        require(to != address(0), "ERC721: mint to the zero address");
        require(!_exists(tokenId), "ERC721: token already minted");
        require(bytes(customURI).length > 0, "ERC721: URI cannot be empty");
        
        _owners[tokenId] = to;
        _balances[to] += 1;
        _customTokenURIs[tokenId] = customURI;

        emit Transfer(address(0), to, tokenId);
    }

    /**
     * @dev Batch mint tokens with custom URIs
     * @param to Address to mint tokens to
     * @param tokenIds Array of token IDs to mint
     * @param customURIs Array of custom URIs corresponding to token IDs
     */
    function batchMintWithURIs(
        address to, 
        uint256[] calldata tokenIds, 
        string[] calldata customURIs
    ) external onlyOwner {
        require(to != address(0), "ERC721: mint to the zero address");
        require(tokenIds.length == customURIs.length, "ERC721: arrays length mismatch");
        
        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];
            string memory customURI = customURIs[i];
            
            require(!_exists(tokenId), "ERC721: token already minted");
            require(bytes(customURI).length > 0, "ERC721: URI cannot be empty");
            
            _owners[tokenId] = to;
            _customTokenURIs[tokenId] = customURI;
        }
        
        _balances[to] += tokenIds.length;
        
        for (uint256 i = 0; i < tokenIds.length; i++) {
            emit Transfer(address(0), to, tokenIds[i]);
        }
    }

    /**
     * @dev Set custom URI for an existing token
     * @param tokenId Token ID to set URI for
     * @param customURI New URI for the token
     */
    function setTokenURI(uint256 tokenId, string memory customURI) public onlyOwner {
        require(_exists(tokenId), "ERC721: URI set for nonexistent token");
        _customTokenURIs[tokenId] = customURI;
    }

    /**
     * @dev Get custom URI for a token (if any)
     * @param tokenId Token ID to query
     * @return Custom URI string (empty if not set)
     */
    function getCustomTokenURI(uint256 tokenId) public view returns (string memory) {
        return _customTokenURIs[tokenId];
    }

    // Auto-increment token ID counter
    uint256 private _currentTokenId = 0;
    
    /**
     * @dev Auto-increment mint with custom URI
     * @param to Address to mint token to
     * @param customURI Custom URI for the token
     * @return tokenId The minted token ID
     */
    function autoMintWithURI(address to, string memory customURI) public onlyOwner returns (uint256) {
        _currentTokenId++;
        uint256 tokenId = _currentTokenId;
        
        mintWithURI(to, tokenId, customURI);
        return tokenId;
    }

    /**
     * @dev See {IERC721-balanceOf}.
     */
    function balanceOf(address tokenOwner) public view returns (uint256) {
        /**code*/
        require(tokenOwner != address(0), "ERC721: balance query for the zero address");
        return _balances[tokenOwner];
    }

    /**
     * @dev See {IERC721-ownerOf}.
     */
    function ownerOf(uint256 tokenId) public view returns (address) {
        /**code*/
        address tokenOwner = _owners[tokenId];
        require(tokenOwner != address(0), "ERC721: owner query for nonexistent token");
        return tokenOwner;
    }

    /**
     * @dev See {IERC721-approve}.
     */
    function approve(address to, uint256 tokenId) public {
        address tokenOwner = ownerOf(tokenId);
        require(to != tokenOwner, "ERC721: approval to current owner");

        require(
            msg.sender == tokenOwner || isApprovedForAll(tokenOwner, msg.sender),
            "ERC721: approve caller is not owner nor approved for all"
        );

       _approve(to, tokenId);
    }

    /**
     * @dev See {IERC721-getApproved}.
     */
    function getApproved(uint256 tokenId) public view returns (address) {
        /**code*/
        require(_exists(tokenId), "ERC721: approved query for nonexistent token");
        return _tokenApprovals[tokenId];
    }

    /**
     * @dev See {IERC721-setApprovalForAll}.
     */
    function setApprovalForAll(address operator, bool approved) public {
        address sender = msg.sender;
        /**code*/
        require(operator != sender, "ERC721: approve to caller");
        _operatorApprovals[sender][operator] = approved;

        emit ApprovalForAll(sender, operator, approved);
    }

    /**
     * @dev See {IERC721-isApprovedForAll}.
     */
    function isApprovedForAll(
        address tokenOwner,
        address operator
    ) public view returns (bool) {
        /**code*/
        return _operatorApprovals[tokenOwner][operator];
    }

    /**
     * @dev See {IERC721-transferFrom}.
     */
    function transferFrom(address from, address to, uint256 tokenId) public {
        require(
            _isApprovedOrOwner(msg.sender, tokenId),
            "ERC721: transfer caller is not owner nor approved"
        );

        _transfer(from, to, tokenId);
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public {
        safeTransferFrom(from, to, tokenId, "");
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) public {
        require(
            _isApprovedOrOwner(msg.sender, tokenId),
            "ERC721: transfer caller is not owner nor approved"
        );
        _safeTransfer(from, to, tokenId, _data);
    }

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * `_data` is additional data, it has no specified format and it is sent in call to `to`.
     *
     * This internal function is equivalent to {safeTransferFrom}, and can be used to e.g.
     * implement alternative mechanisms to perform token transfer, such as signature-based.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function _safeTransfer(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) internal {
        _transfer(from, to, tokenId);
        require(
            _checkOnERC721Received(from, to, tokenId, _data),
            "ERC721: transfer to non ERC721Receiver implementer"
        );
    }

    /**
     * @dev Returns whether `tokenId` exists.
     *
     * Tokens can be managed by their owner or approved accounts via {approve} or {setApprovalForAll}.
     *
     * Tokens start existing when they are minted (`_mint`),
     * and stop existing when they are burned (`_burn`).
     */
    function _exists(uint256 tokenId) internal view returns (bool) {
        /**code*/
        return _owners[tokenId] != address(0);
    }

    /**
     * @dev Returns whether `spender` is allowed to manage `tokenId`.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function _isApprovedOrOwner(
        address spender,
        uint256 tokenId
    ) internal view returns (bool) {
        /**code*/
        require(_exists(tokenId), "ERC721: operator query for nonexistent token");
        address tokenOwner = ownerOf(tokenId);
        return (spender == tokenOwner || getApproved(tokenId) == spender || isApprovedForAll(tokenOwner, spender));
    }

    /**
     * @dev Transfers `tokenId` from `from` to `to`.
     *  As opposed to {transferFrom}, this imposes no restrictions on msg.sender.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     *
     * Emits a {Transfer} event.
     */
    function _transfer(address from, address to, uint256 tokenId) internal {
        /**code*/
        require(ownerOf(tokenId) == from, "ERC721: transfer from incorrect owner");
        require(to != address(0), "ERC721: transfer to the zero address");

        // Clear approvals
        _approve(address(0), tokenId);

        _balances[from] -= 1;
        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(from, to, tokenId);
    }

    /**
     * @dev Approve `to` to operate on `tokenId`
     *
     * Emits a {Approval} event.
     */
    function _approve(address to, uint256 tokenId) internal virtual {
        /**code*/
        _tokenApprovals[tokenId] = to;
        emit Approval(ownerOf(tokenId), to, tokenId);
    }

    /**
     * @dev Burns `tokenId`. See {ERC721-_burn}.
     *
     * Requirements:
     *
     * - The caller must own `tokenId` or be an approved operator.
     */
    function burn(uint256 tokenId) public {
        require(_isApprovedOrOwner(msg.sender, tokenId), "ERC721: caller is not token owner or approved");
        _burn(tokenId);
    }

    /**
     * @dev Destroys `tokenId`.
     * The approval is cleared when the token is burned.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     *
     * Emits a {Transfer} event.
     */
    function _burn(uint256 tokenId) internal {
        address tokenOwner = ownerOf(tokenId);

        // Clear approvals
        _approve(address(0), tokenId);

        _balances[tokenOwner] -= 1;
        delete _owners[tokenId];
        
        // Clear custom URI if exists
        if (bytes(_customTokenURIs[tokenId]).length > 0) {
            delete _customTokenURIs[tokenId];
        }

        emit Transfer(tokenOwner, address(0), tokenId);
    }

    /**
     * @dev Sets a new base URI for all tokens
     * Only the contract owner can call this function
     */
    function setBaseURI(string memory newBaseURI) public onlyOwner {
        _baseURI = newBaseURI;
    }

    /**
     * @dev Returns the base URI for tokens
     */
    function baseURI() public view returns (string memory) {
        return _baseURI;
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0), "BaseERC721: new owner is the zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     */
    function renounceOwnership() public onlyOwner {
        emit OwnershipTransferred(owner, address(0));
        owner = address(0);
    }

    function _isContract(address account) internal view returns (bool) {
    uint256 size;
    assembly { size := extcodesize(account) }
    return size > 0;
}

    /**
     * @dev Internal function to invoke {IERC721Receiver-onERC721Received} on a target address.
     * The call is not executed if the target address is not a contract.
     *
     * @param from address representing the previous owner of the given token ID
     * @param to target address that will receive the tokens
     * @param tokenId uint256 ID of the token to be transferred
     * @param _data bytes optional data to send along with the call
     * @return bool whether the call correctly returned the expected magic value
     */
    function _checkOnERC721Received(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) private returns (bool) {
        if (_isContract(to)) {
            try
                IERC721Receiver(to).onERC721Received(
                    msg.sender,
                    from,
                    tokenId,
                    _data
                )
            returns (bytes4 retval) {
                return retval == IERC721Receiver.onERC721Received.selector;
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert(
                        "ERC721: transfer to non ERC721Receiver implementer"
                    );
                } else {
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        } else {
            return true;
        }
    }
}

contract BaseERC721Receiver is IERC721Receiver {
    constructor() {}

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }
}