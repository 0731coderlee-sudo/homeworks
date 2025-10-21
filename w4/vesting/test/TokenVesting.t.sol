// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/TokenVesting.sol";
import "../src/MockToken.sol";

contract TokenVestingTest is Test {
    TokenVesting public vesting;
    MockToken public token;

    address public beneficiary = address(0x1);
    address public deployer = address(this);

    uint256 public constant VESTING_AMOUNT = 1_000_000 * 1e18; // 100万代币

    function setUp() public {
        // 部署代币
        token = new MockToken();

        // 部署vesting合约
        vesting = new TokenVesting(beneficiary, address(token), VESTING_AMOUNT);

        // 将代币转入vesting合约
        token.transfer(address(vesting), VESTING_AMOUNT);
    }

    function testInitialState() public {
        assertEq(vesting.beneficiary(), beneficiary);
        assertEq(address(vesting.token()), address(token));
        assertEq(vesting.totalAllocation(), VESTING_AMOUNT);
        assertEq(vesting.released(), 0);
    }

    function testCannotReleaseBeforeCliff() public {
        // 在cliff期内不能释放
        vm.warp(block.timestamp + 180 days); // 6个月后
        vm.expectRevert("No tokens to release");
        vesting.release();
    }

    function testReleaseAfterCliff() public {
        // 跳转到cliff后的第13个月
        vm.warp(block.timestamp + 365 days + 30 days);

        uint256 releasable = vesting.releasableAmount();
        assertGt(releasable, 0);

        vesting.release();
        assertEq(token.balanceOf(beneficiary), releasable);
    }

    function testLinearVesting() public {
        // 测试线性释放
        // 第18个月: 应该释放 18/36 = 50%
        vm.warp(block.timestamp + 547 days); // ~18个月

        uint256 expected = (VESTING_AMOUNT * 547 days) / 1095 days;
        uint256 releasable = vesting.releasableAmount();

        assertApproxEqAbs(releasable, expected, 1e18); // 允许小误差
    }

    function testFullVestingAfterDuration() public {
        // 跳转到vesting期结束后
        vm.warp(block.timestamp + 1095 days + 1);

        vesting.release();
        assertEq(token.balanceOf(beneficiary), VESTING_AMOUNT);
        assertEq(vesting.released(), VESTING_AMOUNT);
    }

    function testMultipleReleases() public {
        // 第一次释放 - 第13个月
        vm.warp(block.timestamp + 395 days);
        vesting.release();
        uint256 firstRelease = vesting.released();

        // 第二次释放 - 第24个月
        vm.warp(block.timestamp + 730 days);
        vesting.release();
        uint256 secondRelease = vesting.released();

        assertGt(secondRelease, firstRelease);
    }
}
