// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {Lira} from "../src/Lira.sol";

contract DeployLira is Script {
    function setUp() public {}

    function run() public {
        vm.startBroadcast();
        new Lira();
        vm.stopBroadcast();
    }
}
