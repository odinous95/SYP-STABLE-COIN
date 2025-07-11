// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {LiraEngine} from "../../src/LiraEngine.sol";
import {Lira} from "../../src/Lira.sol";
import {DeployLiraEngine} from "../../script/DeployLira.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";

contract LiraEngineTest is Test {
    DeployLiraEngine deployer;
    HelperConfig helperConfig;
    LiraEngine liraEngine;
    Lira lira;
    address wethPriceFeed;
    address weth;

    function setUp() external {
        deployer = new DeployLiraEngine();
        (lira, liraEngine, helperConfig) = deployer.run();
        (
            address wethAddressPriceFeed,
            address wbtcAddressPriceFeed,
            address wethAddress,
            address wbtcAddress,
            uint256 deployerKey
        ) = helperConfig.activeChainConfig();
        wethPriceFeed = wethAddressPriceFeed;
        weth = wethAddress;
    }

    function testGetUsdValue() public view {
        // Arrange
        uint256 amount = 1 ether; // 1 ETH in wei
        uint256 expectedUsdValue = 2000 * 10 ** 18; // Assuming 1 ETH = $2000
        // Act
        uint256 usdValue = liraEngine.getCollateralPriceInUSD(weth, amount);

        // Assert
        assertEq(usdValue, expectedUsdValue, "USD value should match expected value");
    }
}
