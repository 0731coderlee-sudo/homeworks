// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title TokenVesting
 * @dev 代币线性释放合约
 *
 * 功能说明:
 * - Cliff期: 12个月 - 在此期间内不能释放任何代币
 * - 线性释放期: 24个月 - 从第13个月开始,每月解锁 1/24 的代币
 * - 总锁定期: 36个月 (12个月cliff + 24个月线性释放)
 */
contract TokenVesting {
    using SafeERC20 for IERC20;

    // 受益人地址
    address public immutable beneficiary;

    // 锁定的ERC20代币地址
    IERC20 public immutable token;

    // 合约部署时间(vesting开始时间)
    uint256 public immutable start;

    // Cliff结束时间 (12个月)
    uint256 public immutable cliff;

    // Vesting结束时间 (36个月)
    uint256 public immutable duration;

    // 总锁定代币数量
    uint256 public totalAllocation;

    // 已经释放的代币数量
    uint256 public released;

    // 常量定义
    uint256 public constant CLIFF_DURATION = 365 days;      // 12个月 cliff期
    uint256 public constant VESTING_DURATION = 1095 days;   // 36个月总时长 (12 + 24)

    // 事件
    event TokensReleased(uint256 amount);
    event VestingInitialized(uint256 amount);

    /**
     * @dev 构造函数
     * @param _beneficiary 受益人地址
     * @param _token 锁定的ERC20代币地址
     * @param _amount 要锁定的代币数量
     *
     * 注意: 部署后需要将代币转入合约
     */
    constructor(address _beneficiary, address _token, uint256 _amount) {
        require(_beneficiary != address(0), "Beneficiary is zero address");
        require(_token != address(0), "Token is zero address");
        require(_amount > 0, "Amount must be greater than 0");

        beneficiary = _beneficiary;
        token = IERC20(_token);
        start = block.timestamp;
        cliff = start + CLIFF_DURATION;
        duration = VESTING_DURATION;
        totalAllocation = _amount;

        emit VestingInitialized(_amount);
    }

    /**
     * @dev 释放当前可解锁的代币给受益人
     *
     * 释放逻辑:
     * 1. 如果当前时间 < cliff时间: 不能释放任何代币
     * 2. 如果当前时间 >= cliff && < start + duration: 线性释放
     *    可释放数量 = (总数量 * (当前时间 - 开始时间)) / 总时长 - 已释放数量
     * 3. 如果当前时间 >= start + duration: 释放全部剩余代币
     */
    function release() public {
        uint256 releasable = _releasableAmount();
        require(releasable > 0, "No tokens to release");

        released += releasable;
        token.safeTransfer(beneficiary, releasable);

        emit TokensReleased(releasable);
    }

    /**
     * @dev 计算当前可释放的代币数量
     * @return 可释放的代币数量
     */
    function _releasableAmount() private view returns (uint256) {
        return _vestedAmount() - released;
    }

    /**
     * @dev 计算从开始到现在已经解锁的代币总量(不是可释放量)
     * @return 已解锁的代币总量
     */
    function _vestedAmount() private view returns (uint256) {
        // 如果还没到cliff时间,返回0
        if (block.timestamp < cliff) {
            return 0;
        }

        // 如果已经过了整个vesting期,返回全部
        if (block.timestamp >= start + duration) {
            return totalAllocation;
        }

        // 线性释放计算: (总量 * 已过去的时间) / 总时长
        return (totalAllocation * (block.timestamp - start)) / duration;
    }

    /**
     * @dev 查看当前可释放的代币数量(外部查询函数)
     * @return 当前可释放的代币数量
     */
    function releasableAmount() external view returns (uint256) {
        return _releasableAmount();
    }

    /**
     * @dev 查看已解锁但未释放的代币数量
     * @return 已解锁的总代币数量
     */
    function vestedAmount() external view returns (uint256) {
        return _vestedAmount();
    }
}
