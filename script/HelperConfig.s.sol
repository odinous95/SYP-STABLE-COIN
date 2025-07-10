// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {Lira} from "../src/Lira.sol";
import {LiraEngine} from "../src/LiraEngine.sol";

abstract contract ChainParameters is Script {
    address wethAddressPriceFeed = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
    address wbtcAddressPriceFeed = 0xA39434A63A52E749F02807ae27335515BA4b07F7;
    address ethAddress = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address wbtcAddress = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;

    constructor() {}
}

contract HelperConfig is Script, ChainParameters {
    struct ChainConfig {
        address wethAddressPriceFeed;
        address wbtcAddressPriceFeed;
        address ethAddress;
        address wbtcAddress;
        uint256 deployerKey;
    }

    ChainConfig public activeChainConfig;

    constructor() {}

    /**
     * @notice This function is used to get the configuration for the Sepolia network.
     * It returns a ChainConfig struct containing the addresses of WETH and WBTC price feeds,
     * as well as the addresses of ETH and WBTC tokens, and the deployer key.
     */
    function getSepoliaETHConfig() public returns (ChainConfig memory) {
        return ChainConfig({
            wethAddressPriceFeed: ChainParameters.wethAddressPriceFeed,
            wbtcAddressPriceFeed: ChainParameters.wbtcAddressPriceFeed,
            ethAddress: ChainParameters.ethAddress,
            wbtcAddress: ChainParameters.wbtcAddress,
            deployerKey: vm.envUint("PRIVATE_KEY")
        });
    }
}
