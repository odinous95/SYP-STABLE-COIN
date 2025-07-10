// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {Lira} from "../src/Lira.sol";
import {LiraEngine} from "../src/LiraEngine.sol";
import {MockV3Aggregator} from "../test/mocks/MockV3Aggregator.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

abstract contract ChainParameters is Script {
    address wethAddressPriceFeed = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
    address wbtcAddressPriceFeed = 0xA39434A63A52E749F02807ae27335515BA4b07F7;
    address ethAddress = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address wbtcAddress = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;

    // Local Anvil key for testing purposes
    uint256 localAnvilKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
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
    /**
     * @notice This function retrieves the active chain configuration.
     * If the WETH address price feed is not set, it initializes the activeChainConfig
     * with the local anvil configuration.
     * @return ChainConfig The active chain configuration.
     */

    function getActiveChainConfig() public returns (ChainConfig memory) {
        if (activeChainConfig.wethAddressPriceFeed == address(0)) {
            return activeChainConfig;
        }

        vm.startBroadcast();
        // ETH price feed mock and ERC20 mock
        MockV3Aggregator ethUsdPriceFeed = new MockV3Aggregator(8, 2000e8);
        ERC20Mock wethMock = new ERC20Mock();

        // BTC price feed mock and ERC20 mock
        MockV3Aggregator btcUsdPriceFeed = new MockV3Aggregator(8, 20000e8);
        ERC20Mock wbtcMock = new ERC20Mock();
        return ChainConfig({
            wethAddressPriceFeed: address(ethUsdPriceFeed),
            wbtcAddressPriceFeed: address(btcUsdPriceFeed),
            ethAddress: address(wethMock),
            wbtcAddress: address(wbtcMock),
            deployerKey: ChainParameters.localAnvilKey
        });
    }
}
