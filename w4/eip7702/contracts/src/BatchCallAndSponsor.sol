// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

/**
 * @title BatchCallAndSponsor
 * @notice An educational contract that allows batch execution of calls with nonce and signature verification.
 *
 * When an EOA upgrades via EIP‑7702, it delegates to this implementation.
 * Off‑chain, the account signs a message authorizing a batch of calls using EIP-712 standard.
 * The signature includes:
 *    - Domain separator (with chainId for cross-chain replay protection)
 *    - Typed data hash of the batch (nonce + calls)
 * The signature must be generated with the EOA's private key so that, once upgraded, the recovered signer equals the account's own address (i.e. the EOA address).
 *
 * This contract provides two ways to execute a batch:
 * 1. With a signature: Any sponsor can submit the batch if it carries a valid signature.
 * 2. Directly by the smart account: When the account itself calls the function, no signature is required.
 *
 * Replay protection is achieved by:
 * - Nonce included in the signed message (prevents replay in same chain)
 * - ChainId in domain separator (prevents replay across different chains)
 */
contract BatchCallAndSponsor {
    using ECDSA for bytes32;

    /// @notice The original EOA address that this contract represents
    address public immutable eoaAddress;

    /// @notice A nonce used for replay protection.
    uint256 public nonce;

    /// @notice Maximum number of calls allowed in a single batch
    uint256 public constant MAX_CALLS = 20;

    // EIP-712 Type Hashes
    bytes32 private constant DOMAIN_TYPEHASH = keccak256(
        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
    );

    bytes32 private constant CALL_TYPEHASH = keccak256(
        "Call(address to,uint256 value,bytes data)"
    );

    bytes32 private constant BATCH_TYPEHASH = keccak256(
        "Batch(uint256 nonce,Call[] calls)Call(address to,uint256 value,bytes data)"
    );

    /// @notice Represents a single call within a batch.
    struct Call {
        address to;
        uint256 value;
        bytes data;
    }

    /// @notice Emitted for every individual call executed.
    event CallExecuted(address indexed sender, address indexed to, uint256 value, bytes data);
    /// @notice Emitted when a full batch is executed.
    event BatchExecuted(uint256 indexed nonce, Call[] calls);

    /**
     * @dev Constructor
     * @param _eoaAddress The original EOA address that will delegate to this contract
     */
    constructor(address _eoaAddress) {
        require(_eoaAddress != address(0), "Invalid EOA address");
        eoaAddress = _eoaAddress;
    }

    /**
     * @notice Executes a batch of calls using an off–chain signature.
     * @param calls An array of Call structs containing destination, ETH value, and calldata.
     * @param signature The ECDSA signature over the EIP-712 typed data hash.
     *
     * The signature must be produced off–chain by signing the EIP-712 typed data hash.
     * The signing key should be the account's key (which becomes the smart account's own identity after upgrade).
     */
    function execute(Call[] calldata calls, bytes calldata signature) external payable {
        // Compute the EIP-712 digest that the account was expected to sign.
        uint256 currentNonce = nonce;
        bytes32 structHash = _hashBatch(currentNonce, calls);
        bytes32 typedDataHash = _toTypedDataHash(structHash);

        // Recover the signer from the provided signature.
        // In EIP-7702, the signer should be the original EOA address
        address recovered = ECDSA.recover(typedDataHash, signature);
        require(recovered == eoaAddress, "Invalid signature");

        _executeBatch(calls);
    }

    /**
     * @notice Executes a batch of calls directly.
     * @dev This function is intended for use when the smart account itself (i.e. address(this))
     * calls the contract. It checks that msg.sender is the contract itself.
     * @param calls An array of Call structs containing destination, ETH value, and calldata.
     */
    function execute(Call[] calldata calls) external payable {
        require(msg.sender == address(this), "Invalid authority");
        _executeBatch(calls);
    }

    /**
     * @notice Returns the EIP-712 digest that needs to be signed for the given batch with the current nonce.
     * @dev Helps users compute the exact message off-chain when preparing their signatures.
     * @param calls The batch that will be executed.
     * @return typedDataHash The EIP-712 typed data hash ready for ECDSA signing.
     */
    function digest(Call[] calldata calls) external view returns (bytes32 typedDataHash) {
        bytes32 structHash = _hashBatch(nonce, calls);
        typedDataHash = _toTypedDataHash(structHash);
    }

    /**
     * @dev Internal function that handles batch execution and nonce incrementation.
     * @param calls An array of Call structs.
     */
    function _executeBatch(Call[] calldata calls) internal {
        require(calls.length > 0, "Empty batch");
        require(calls.length <= MAX_CALLS, "Too many calls");

        uint256 currentNonce = nonce;
        nonce++; // Increment nonce to protect against replay attacks

        for (uint256 i = 0; i < calls.length; i++) {
            _executeCall(calls[i]);
        }

        emit BatchExecuted(currentNonce, calls);
    }

    /**
     * @dev Internal function to execute a single call.
     * @param callItem The Call struct containing destination, value, and calldata.
     */
    function _executeCall(Call calldata callItem) internal {
        (bool success, bytes memory returnData) = callItem.to.call{value: callItem.value}(callItem.data);

        if (!success) {
            // If there's return data, bubble up the original error
            if (returnData.length > 0) {
                // Bubble up the revert reason from the failed call
                assembly {
                    let returnDataSize := mload(returnData)
                    revert(add(32, returnData), returnDataSize)
                }
            } else {
                // No revert reason provided
                revert("Call reverted without reason");
            }
        }

        emit CallExecuted(msg.sender, callItem.to, callItem.value, callItem.data);
    }

    /**
     * @dev Returns the EIP-712 domain separator for this contract.
     * @return The domain separator hash.
     */
    function _domainSeparator() internal view returns (bytes32) {
        return keccak256(abi.encode(
            DOMAIN_TYPEHASH,
            keccak256(bytes("BatchCallAndSponsor")),
            keccak256(bytes("1")),
            block.chainid,
            address(this)
        ));
    }

    /**
     * @dev Converts a struct hash to an EIP-712 typed data hash.
     * @param structHash The hash of the struct to convert.
     * @return The EIP-712 typed data hash.
     */
    function _toTypedDataHash(bytes32 structHash) internal view returns (bytes32) {
        return keccak256(abi.encodePacked(
            "\x19\x01",
            _domainSeparator(),
            structHash
        ));
    }

    /**
     * @dev Hashes the batch according to EIP-712 standard.
     * @param nonceToHash The nonce that should be part of the signed payload.
     * @param calls The batch of calls to hash.
     * @return structHash The EIP-712 struct hash of the batch.
     */
    function _hashBatch(uint256 nonceToHash, Call[] calldata calls) internal pure returns (bytes32 structHash) {
        // Hash each individual call
        bytes32[] memory callHashes = new bytes32[](calls.length);
        for (uint256 i = 0; i < calls.length; i++) {
            callHashes[i] = keccak256(abi.encode(
                CALL_TYPEHASH,
                calls[i].to,
                calls[i].value,
                keccak256(calls[i].data)
            ));
        }

        // Hash the array of call hashes
        bytes32 callsHash = keccak256(abi.encodePacked(callHashes));

        // Encode the Batch struct
        structHash = keccak256(abi.encode(
            BATCH_TYPEHASH,
            nonceToHash,
            callsHash
        ));
    }

    // Allow the contract to receive ETH (e.g. from DEX swaps or other transfers).
    fallback() external payable {}
    receive() external payable {}
}
