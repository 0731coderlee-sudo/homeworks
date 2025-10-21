// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MockUniswapV2Pair {
    string public name = "Uniswap V2";
    string public symbol = "UNI-V2";
    uint8 public decimals = 18;
    uint256 public totalSupply;

    address public token0;
    address public token1;
    uint112 private reserve0;
    uint112 private reserve1;

    mapping(address => uint256) public balanceOf;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Sync(uint112 reserve0, uint112 reserve1);
    event Mint(address indexed sender, uint256 amount0, uint256 amount1);

    constructor(address _token0, address _token1) {
        token0 = _token0;
        token1 = _token1;
    }

    function getReserves() public view returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast) {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
        _blockTimestampLast = uint32(block.timestamp);
    }

    function mint(address to) external returns (uint256 liquidity) {
        // 简化的 mint 逻辑
        liquidity = 1000 ether; // 固定返回流动性
        balanceOf[to] += liquidity;
        totalSupply += liquidity;
        emit Transfer(address(0), to, liquidity);
        return liquidity;
    }

    function sync() external {
        emit Sync(reserve0, reserve1);
    }

    // 手动设置储备金（用于测试）
    function setReserves(uint112 _reserve0, uint112 _reserve1) external {
        reserve0 = _reserve0;
        reserve1 = _reserve1;
        emit Sync(reserve0, reserve1);
    }

    // 辅助函数：从 pair 转移 token（用于 swap）
    function transferToken(address token, address to, uint256 amount) external {
        // 简化版本：直接调用 token 的 transfer
        // 在真实的 Uniswap 中，token 已经在 pair 的余额中
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSignature("transfer(address,uint256)", to, amount)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "TRANSFER_FAILED");
    }
}
