// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/BatchCallAndSponsor.sol";
import "../src/tokenbank.sol";
import "../src/ttcoin.sol";

contract BatchCallAndSponsorTest is Test {
    uint256 private constant EOA_PRIVATE_KEY = 0xA11CE; 
    address payable private eoa;                       
    address private sponsor;

    TTCoin private token;
    TokenBank private bank;
    BatchCallAndSponsor private smartAccount;

    function setUp() public {
        eoa = payable(vm.addr(EOA_PRIVATE_KEY));
        //代替 EOA 支付 gas 的账户（体现赞助模式）
        sponsor = vm.addr(0xB0B);
        //部署合约生态
        token = new TTCoin(1_000_000, "Test Token", "TTK");
        bank = new TokenBank(address(token));
        // 给 EOA 一些代币用于测试
        bool transferred = token.transfer(eoa, 1_000 ether);
        assertTrue(transferred, "token transfer to EOA failed");

        // 模拟 EIP-7702 升级
        // 1.部署逻辑合约 （标记这是(eoa)智能账户）
        BatchCallAndSponsor logic = new BatchCallAndSponsor(eoa);
        // 2.使用 vm.etch 覆写代码 - Foundry 作弊码，可以直接修改某个地址的合约代码 
        //把 BatchCallAndSponsor 的字节码安装到 EOA 的地
        //EOA 现在不再是普通账户，而是一个智能合约！
//         类比现实 EIP-7702：
//   真实的 EIP-7702 交易类型（0x04）会告诉以太坊虚拟机：
//   "在这次交易执行期间，把地址 X 当作合约 Y 来执行" 测试中用 vm.etch 永久模拟这个效果（因为 Foundry 测试环境不支持真实的 EIP-7702）
        vm.etch(eoa, address(logic).code);
        // 3.创建智能账户引用
        //把 EOA 地址强制转换为 BatchCallAndSponsor 类型
        //现在可以调用 smartAccount.execute() 等智能合约函数
        //但调用时使用的是 EOA 的地址！
        smartAccount = BatchCallAndSponsor(eoa);
        //vm.deal(eoa, 1 ether);     // 给 EOA 分配 1 ETH（用于支付 gas）
        vm.deal(eoa, 1 ether);
        vm.label(eoa, "EOA");
        vm.label(sponsor, "Sponsor");
    }

    function testBatchApproveAndDeposit() public {
        uint256 amount = 100 ether;

        BatchCallAndSponsor.Call[] memory calls = new BatchCallAndSponsor.Call[](2);
        calls[0] = BatchCallAndSponsor.Call({
            to: address(token),
            value: 0,
            data: abi.encodeWithSelector(token.approve.selector, address(bank), amount)
        });
        calls[1] = BatchCallAndSponsor.Call({
            to: address(bank),
            value: 0,
            data: abi.encodeWithSelector(TokenBank.deposit.selector, amount)
        });

        // Get EIP-712 digest (already includes domain separator and proper encoding)
        bytes32 typedDataHash = smartAccount.digest(calls);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(EOA_PRIVATE_KEY, typedDataHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.prank(sponsor);
        smartAccount.execute(calls, signature);

        assertEq(bank.balanceOf(eoa), amount, "bank should credit the EOA deposit");
        assertEq(token.balanceOf(address(bank)), amount, "bank should receive tokens");
        assertEq(smartAccount.nonce(), 1, "nonce should increment");
        assertEq(token.allowance(eoa, address(bank)), 0, "allowance should be consumed");
    }

    function testNonceAfterEtch() public view {
        assertEq(smartAccount.nonce(), 0, "nonce should start at zero");
    }

    function testExecuteRevertsWithInvalidSignature() public {
        BatchCallAndSponsor.Call[] memory calls = new BatchCallAndSponsor.Call[](1);
        calls[0] = BatchCallAndSponsor.Call({
            to: address(bank),
            value: 0,
            data: abi.encodeWithSelector(TokenBank.deposit.selector, 1 ether)
        });

        // Get EIP-712 digest but sign with wrong key
        bytes32 typedDataHash = smartAccount.digest(calls);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(0xBEEF, typedDataHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.expectRevert("Invalid signature");
        vm.prank(sponsor);
        smartAccount.execute(calls, signature);
    }
}
