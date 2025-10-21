// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./MockUniswapV2Factory.sol";
import "./MockUniswapV2Pair.sol";
import "./MockWETH.sol";

interface IERC20 {
    function transferFrom(address from, address to, uint256 value) external returns (bool);
    function transfer(address to, uint256 value) external returns (bool);
}

contract MockUniswapV2Router {
    address public immutable factory;
    address payable public immutable WETH;

    constructor(address _factory, address payable _weth) {
        factory = _factory;
        WETH = _weth;
    }

    receive() external payable {}

    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity) {
        require(deadline >= block.timestamp, "EXPIRED");

        // 获取或创建交易对
        address pair = MockUniswapV2Factory(factory).getPair(token, WETH);
        if (pair == address(0)) {
            pair = MockUniswapV2Factory(factory).createPair(token, WETH);
        }

        // 转移 token 到 pair
        IERC20(token).transferFrom(msg.sender, pair, amountTokenDesired);

        // 转移 ETH 到 pair（包装成 WETH）
        MockWETH(WETH).deposit{value: msg.value}();
        IERC20(WETH).transfer(pair, msg.value);

        // 铸造流动性代币
        liquidity = MockUniswapV2Pair(pair).mint(to);

        // 更新储备金（用于价格计算）
        (uint112 reserve0, uint112 reserve1,) = MockUniswapV2Pair(pair).getReserves();
        if (reserve0 == 0 && reserve1 == 0) {
            // 第一次添加流动性，设置初始储备金
            if (token < WETH) {
                MockUniswapV2Pair(pair).setReserves(uint112(amountTokenDesired), uint112(msg.value));
            } else {
                MockUniswapV2Pair(pair).setReserves(uint112(msg.value), uint112(amountTokenDesired));
            }
        } else {
            // 后续添加，按比例更新
            if (token < WETH) {
                MockUniswapV2Pair(pair).setReserves(
                    uint112(uint256(reserve0) + amountTokenDesired),
                    uint112(uint256(reserve1) + msg.value)
                );
            } else {
                MockUniswapV2Pair(pair).setReserves(
                    uint112(uint256(reserve0) + msg.value),
                    uint112(uint256(reserve1) + amountTokenDesired)
                );
            }
        }

        return (amountTokenDesired, msg.value, liquidity);
    }

    function swapExactETHForTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable returns (uint[] memory amounts) {
        require(deadline >= block.timestamp, "EXPIRED");
        require(path[0] == WETH, "INVALID_PATH");

        amounts = new uint[](path.length);
        amounts[0] = msg.value;

        // 获取交易对
        address pair = MockUniswapV2Factory(factory).getPair(path[0], path[1]);
        require(pair != address(0), "PAIR_NOT_FOUND");

        // 获取储备金
        (uint112 reserve0, uint112 reserve1,) = MockUniswapV2Pair(pair).getReserves();

        // 确定储备金顺序
        (uint112 reserveIn, uint112 reserveOut) = path[0] < path[1]
            ? (reserve0, reserve1)
            : (reserve1, reserve0);

        // 计算输出数量（使用恒定乘积公式 x * y = k）
        amounts[1] = getAmountOut(msg.value, reserveIn, reserveOut);
        require(amounts[1] >= amountOutMin, "INSUFFICIENT_OUTPUT_AMOUNT");

        // 执行交换
        // 包装 ETH 为 WETH
        MockWETH(WETH).deposit{value: msg.value}();
        IERC20(WETH).transfer(pair, msg.value);

        // 转移 token 给接收者（通过 pair 的辅助函数）
        MockUniswapV2Pair(pair).transferToken(path[1], to, amounts[1]);

        // 更新储备金
        if (path[0] < path[1]) {
            MockUniswapV2Pair(pair).setReserves(
                uint112(uint256(reserveIn) + msg.value),
                uint112(uint256(reserveOut) - amounts[1])
            );
        } else {
            MockUniswapV2Pair(pair).setReserves(
                uint112(uint256(reserveOut) - amounts[1]),
                uint112(uint256(reserveIn) + msg.value)
            );
        }

        return amounts;
    }

    function getAmountsOut(
        uint amountIn,
        address[] calldata path
    ) external view returns (uint[] memory amounts) {
        require(path.length >= 2, "INVALID_PATH");
        amounts = new uint[](path.length);
        amounts[0] = amountIn;

        for (uint i; i < path.length - 1; i++) {
            address pair = MockUniswapV2Factory(factory).getPair(path[i], path[i + 1]);
            require(pair != address(0), "PAIR_NOT_FOUND");

            (uint112 reserve0, uint112 reserve1,) = MockUniswapV2Pair(pair).getReserves();
            (uint112 reserveIn, uint112 reserveOut) = path[i] < path[i + 1]
                ? (reserve0, reserve1)
                : (reserve1, reserve0);

            amounts[i + 1] = getAmountOut(amounts[i], reserveIn, reserveOut);
        }

        return amounts;
    }

    // 使用 Uniswap V2 公式计算输出数量
    function getAmountOut(
        uint amountIn,
        uint reserveIn,
        uint reserveOut
    ) internal pure returns (uint amountOut) {
        require(amountIn > 0, "INSUFFICIENT_INPUT_AMOUNT");
        require(reserveIn > 0 && reserveOut > 0, "INSUFFICIENT_LIQUIDITY");

        uint amountInWithFee = amountIn * 997; // 0.3% 手续费
        uint numerator = amountInWithFee * reserveOut;
        uint denominator = (reserveIn * 1000) + amountInWithFee;
        amountOut = numerator / denominator;
    }
}
