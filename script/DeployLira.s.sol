// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {Lira} from "../src/Lira.sol";
import {LiraEngine} from "../src/LiraEngine.sol";

contract DeployLira is Script {
        function run() external returns (Lira, LiraEngine) {
        vm.startBroadcast();
Lira lira =         new Lira();
//address[] memory collateralAddresses, address[] memory priceFeedAddresses, address liraTokenAddress
        LiraEngine liraEngine = new LiraEngine(,,lira.address());
        vm.stopBroadcast();
    }
}
