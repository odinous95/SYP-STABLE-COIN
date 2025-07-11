// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {Lira} from "../src/Lira.sol";
import {LiraEngine} from "../src/LiraEngine.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployLiraEngine is Script {
    address[] public collateralAddresses;
    address[] public priceFeedsAdresses;

    function run() external returns (Lira, LiraEngine) {
        HelperConfig config = new HelperConfig();
        HelperConfig.ChainConfig memory chainConfig = config.getActiveChainConfig();

        address wethAddressPriceFeed = chainConfig.wethAddressPriceFeed;
        address wbtcAddressPriceFeed = chainConfig.wbtcAddressPriceFeed;
        address wethAddress = chainConfig.wethAddress;
        address wbtcAddress = chainConfig.wbtcAddress;
        // uint256 deployerKey = chainConfig.deployerKey;

        // Set up the collateral and price feed addresses
        collateralAddresses = [wethAddress, wbtcAddress];
        priceFeedsAdresses = [wethAddressPriceFeed, wbtcAddressPriceFeed];

        vm.startBroadcast();
        Lira lira = new Lira();
        LiraEngine liraEngine = new LiraEngine(collateralAddresses, priceFeedsAdresses, address(lira));
        // Initialize the Lira contract with the LiraEngine address only
        lira.transferOwnership(address(liraEngine));
        vm.stopBroadcast();
        return (lira, liraEngine);
    }
}
