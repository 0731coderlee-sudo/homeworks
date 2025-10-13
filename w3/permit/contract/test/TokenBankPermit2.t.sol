// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/ttcoin.sol";
import "../src/tokenbank.sol";
import "../src/SimplePermit2.sol";

contract TokenBankPermit2Test is Test {
    ttcoin public token;
    TokenBank public bank;
    SimplePermit2 public permit2;
    
    address public user;
    uint256 public userPrivateKey = 0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef;
    
    function setUp() public {
        // 从私钥生成地址
        user = vm.addr(userPrivateKey);
        
        // 部署合约
        permit2 = new SimplePermit2();
        token = new ttcoin(1000000 * 10**18, "TT Coin", "TTC");
        bank = new TokenBank(IERC20(address(token)), IPermit2(address(permit2)));
        
        // 给测试用户一些代币
        token.transfer(user, 10000 * 10**18);
    }
    
    function testDepositWithPermit2() public {
        uint256 depositAmount = 100 * 10**18;
        uint256 nonce = 0;
        uint256 deadline = block.timestamp + 1 hours;
        
        // 用户需要先授权 Permit2
        vm.prank(user);
        token.approve(address(permit2), depositAmount);
        
        // 构造 Permit2 消息
        bytes32 tokenPermissionsHash = keccak256(abi.encode(
            permit2.TOKEN_PERMISSIONS_TYPEHASH(),
            address(token),
            depositAmount
        ));
        
        bytes32 msgHash = keccak256(abi.encode(
            permit2.PERMIT_TRANSFER_FROM_TYPEHASH(),
            tokenPermissionsHash,
            address(bank),  // spender
            nonce,
            deadline
        ));
        
        bytes32 digest = keccak256(abi.encodePacked(
            "\x19\x01",
            permit2.DOMAIN_SEPARATOR(),
            msgHash
        ));
        
        // 用户签名
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);
        
        // 执行 depositWithPermit2
        bank.depositWithPermit2(user, depositAmount, nonce, deadline, signature);
        
        // 验证存款成功
        assertEq(bank.balanceOf(user), depositAmount);
        assertEq(token.balanceOf(address(bank)), depositAmount);
    }
}