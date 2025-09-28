// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract DataStorage {
    string private data;

    function setData(string memory newData) public {
        data = newData;
    }

    function getData() public view returns (string memory) {
        return data;
    }
}

contract DataConsumer {
    address private dataStorageAddress;

    constructor(address _dataStorageAddress) {
        dataStorageAddress = _dataStorageAddress;
    }

    function getDataByABI() public returns (string memory) {
        // payload - 编码 getData() 函数调用
        bytes memory payload = abi.encodeWithSignature("getData()");
        (bool success, bytes memory data) = dataStorageAddress.call(payload);
        require(success, "call function failed");
        
        // return data - 解码返回的数据
        return abi.decode(data, (string));
    }

    function setDataByABI1(string calldata newData) public returns (bool) {
        // payload - 使用 abi.encodeWithSignature() 编码 setData 函数调用
        bytes memory payload = abi.encodeWithSignature("setData(string)", newData);
        (bool success, ) = dataStorageAddress.call(payload);

        return success;
    }

    function setDataByABI2(string calldata newData) public returns (bool) {
        // selector - 计算 setData(string) 的函数选择器
        bytes4 selector = bytes4(keccak256("setData(string)"));
        // payload - 使用 abi.encodeWithSelector() 编码函数调用
        bytes memory payload = abi.encodeWithSelector(selector, newData);

        (bool success, ) = dataStorageAddress.call(payload);

        return success;
    }

    function setDataByABI3(string calldata newData) public returns (bool) {
        // payload - 使用 abi.encodeCall() 编码函数调用 (Solidity 0.8.11+)
        bytes memory payload = abi.encodeCall(DataStorage.setData, (newData));

        (bool success, ) = dataStorageAddress.call(payload);
        return success;
    }
}
