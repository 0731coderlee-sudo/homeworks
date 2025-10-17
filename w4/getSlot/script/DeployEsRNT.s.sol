// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../src/esRNT.sol";
import "forge-std/Script.sol";

contract DeployEsRNT is Script {
    function run() external {
        vm.startBroadcast();
        new esRNT();
        vm.stopBroadcast();
    }
}
