// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {LiraEngine} from "../../src/LiraEngine.sol";
import {Lira} from "../../src/Lira.sol";
import {DeployLiraEngine} from "../../script/DeployLira.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract LiraEngineTest is Test {
    DeployLiraEngine deployer;
    HelperConfig helperConfig;
    LiraEngine liraEngine;
    Lira lira;
    address wethPriceFeed;
    address weth;

    address public USER = makeAddr("user");
    uint256 public COLLATERAL_AMOUNT = 1 ether; // 1 ETH in wei
    uint256 public TOKEN_AMOUNT = 1000 * 10 ** 18; // 1000 LIRA tokens in wei

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
        ERC20Mock(weth).mint(USER, TOKEN_AMOUNT);
    }
    // pirce tests

    function testGetUsdValue() public view {
        // Arrange
        uint256 amount = 1 ether; // 1 ETH in wei
        uint256 expectedUsdValue = 2000 * 10 ** 18; // Assuming 1 ETH = $2000
        // Act
        uint256 usdValue = liraEngine.getCollateralPriceInUSD(weth, amount);
        // Assert
        assertEq(usdValue, expectedUsdValue, "USD value should match expected value");
    }

    // collateral tests

    function testRevertIfCollateralZero() public {
        // Arrange
        vm.startPrank(USER);
        // We need to approve the LiraEngine to spend our WETH with the correct amount
        ERC20Mock(weth).approve(address(liraEngine), COLLATERAL_AMOUNT);

        // Act & Assert
        // Here we expect the revert to be thrown when we try to deposit zero collateral even though
        //we have approved the LiraEngine to spend our WETH
        vm.expectRevert(abi.encodeWithSelector(LiraEngine.liraEngine_greaterThanZero.selector, 0));
        // Attempt to deposit zero collateral
        liraEngine.depositCollateral(weth, 0);
        vm.stopPrank();
    }
}
