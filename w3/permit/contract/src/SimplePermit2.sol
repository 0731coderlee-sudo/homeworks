// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "./interfaces.sol";

/// @notice 简化版 Permit2 合约用于本地测试
contract SimplePermit2 {
    // EIP-712 域分隔符
    bytes32 public immutable DOMAIN_SEPARATOR;
    string public constant name = "Permit2";
    
    // 类型哈希
    bytes32 public constant PERMIT_TRANSFER_FROM_TYPEHASH = 
        keccak256("PermitTransferFrom(TokenPermissions permitted,address spender,uint256 nonce,uint256 deadline)TokenPermissions(address token,uint256 amount)");
    bytes32 public constant TOKEN_PERMISSIONS_TYPEHASH = 
        keccak256("TokenPermissions(address token,uint256 amount)");
    
    // 已使用的 nonce
    mapping(address => mapping(uint256 => bool)) public usedNonces;
    
    struct TokenPermissions {
        address token;
        uint256 amount;
    }

    struct PermitTransferFrom {
        TokenPermissions permitted;
        uint256 nonce;
        uint256 deadline;
    }

    struct SignatureTransferDetails {
        address to;
        uint256 requestedAmount;
    }

    constructor() {
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract)"),
                keccak256(bytes(name)),
                block.chainid,
                address(this)
            )
        );
    }

    function permitTransferFrom(
        PermitTransferFrom calldata permit,
        SignatureTransferDetails calldata transferDetails,
        address owner,
        bytes calldata signature
    ) external {
        require(block.timestamp <= permit.deadline, "Permit2: expired");
        require(!usedNonces[owner][permit.nonce], "Permit2: nonce used");
        
        // 标记 nonce 已使用
        usedNonces[owner][permit.nonce] = true;
        
        // 构造 EIP-712 消息哈希
        bytes32 tokenPermissionsHash = keccak256(abi.encode(
            TOKEN_PERMISSIONS_TYPEHASH,
            permit.permitted.token,
            permit.permitted.amount
        ));
        
        bytes32 msgHash = keccak256(abi.encode(
            PERMIT_TRANSFER_FROM_TYPEHASH,
            tokenPermissionsHash,
            msg.sender,  // spender
            permit.nonce,
            permit.deadline
        ));
        
        bytes32 digest = keccak256(abi.encodePacked(
            "\x19\x01",
            DOMAIN_SEPARATOR,
            msgHash
        ));
        
        // 验证签名
        address signer = recoverSigner(digest, signature);
        require(signer == owner, "Permit2: invalid signature");
        
        // 执行转账
        require(
            IERC20(permit.permitted.token).transferFrom(owner, transferDetails.to, transferDetails.requestedAmount),
            "Permit2: transfer failed"
        );
    }
    
    function recoverSigner(bytes32 hash, bytes calldata signature) internal pure returns (address) {
        require(signature.length == 65, "Permit2: invalid signature length");
        
        bytes32 r;
        bytes32 s;
        uint8 v;
        
        assembly {
            r := calldataload(signature.offset)
            s := calldataload(add(signature.offset, 32))
            v := byte(0, calldataload(add(signature.offset, 64)))
        }
        
        return ecrecover(hash, v, r, s);
    }
}