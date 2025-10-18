// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// ERC1967 代理合约 - 用于 UUPS 可升级模式
// 这是一个最小化的代理合约实现
//
// 使用说明：
// 1. 部署此代理合约，构造函数传入实现合约地址
// 2. 代理合约会自动调用实现合约的 initialize() 函数
// 3. 之后所有调用都会被转发到实现合约
// 4. 升级时调用实现合约的 upgradeTo(newImplementation) 函数
contract NFTMarketV2Proxy {

    // ERC1967 标准存储槽位：用于存储实现合约地址
    // keccak256("eip1967.proxy.implementation") - 1
    bytes32 private constant IMPLEMENTATION_SLOT =
        0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    // ERC1967 标准存储槽位：用于存储管理员地址
    // keccak256("eip1967.proxy.admin") - 1
    bytes32 private constant ADMIN_SLOT =
        0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

    // 事件：实现合约升级
    event Upgraded(address indexed implementation);

    // 事件：管理员变更
    event AdminChanged(address previousAdmin, address newAdmin);

    // 构造函数
    // _implementation: 实现合约地址（已部署的 NFTMarketV2Upgradeable）
    constructor(address _implementation) {
        // 设置管理员为部署者
        _setAdmin(msg.sender);

        // 设置实现合约地址
        _setImplementation(_implementation);

        // 调用实现合约的 initialize() 函数
        // 这会初始化实现合约的状态（通过代理存储）
        (bool success, ) = _implementation.delegatecall(
            abi.encodeWithSignature("initialize()")
        );
        require(success, "Initialization failed");
    }

    // 回退函数：将所有调用转发到实现合约
    fallback() external payable {
        _delegate(_getImplementation());
    }

    // 接收 ETH
    receive() external payable {
        _delegate(_getImplementation());
    }

    // 内部函数：委托调用
    function _delegate(address impl) internal {
        assembly {
            // 复制调用数据到内存
            calldatacopy(0, 0, calldatasize())

            // 委托调用实现合约
            let result := delegatecall(gas(), impl, 0, calldatasize(), 0, 0)

            // 复制返回数据到内存
            returndatacopy(0, 0, returndatasize())

            switch result
            // 如果调用失败，回滚
            case 0 {
                revert(0, returndatasize())
            }
            // 如果调用成功，返回数据
            default {
                return(0, returndatasize())
            }
        }
    }

    // 内部函数：设置实现合约地址
    function _setImplementation(address newImplementation) private {
        require(newImplementation != address(0), "Invalid implementation");

        assembly {
            sstore(IMPLEMENTATION_SLOT, newImplementation)
        }

        emit Upgraded(newImplementation);
    }

    // 内部函数：获取实现合约地址
    function _getImplementation() private view returns (address impl) {
        assembly {
            impl := sload(IMPLEMENTATION_SLOT)
        }
    }

    // 内部函数：设置管理员
    function _setAdmin(address newAdmin) private {
        assembly {
            sstore(ADMIN_SLOT, newAdmin)
        }

        emit AdminChanged(address(0), newAdmin);
    }

    // 内部函数：获取管理员
    function _getAdmin() private view returns (address adminAddr) {
        assembly {
            adminAddr := sload(ADMIN_SLOT)
        }
    }

    // 查看函数：获取当前实现合约地址
    // 注意：这个函数不会被代理，直接在代理合约执行
    function implementation() external view returns (address) {
        return _getImplementation();
    }

    // 查看函数：获取当前管理员
    function admin() external view returns (address) {
        return _getAdmin();
    }
}
