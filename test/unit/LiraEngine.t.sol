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
    address wbtcPriceFeed;
    address wbtc;
    address public USER = makeAddr("user");
    address public LIQUIDATOR = makeAddr("liquidator");
    uint256 public COLLATERAL_AMOUNT = 13 ether; // 1 ETH in wei
    uint256 public TOKEN_AMOUNT = 1000 * 10 ** 18; // 1000 LIRA tokens in wei
    uint256 private constant MIN_HEALTH_FACTOR = 1e18; // Minimum health factor to avoid liquidation

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
        wbtcPriceFeed = wbtcAddressPriceFeed;
        wbtc = wbtcAddress;
        ERC20Mock(weth).mint(USER, TOKEN_AMOUNT);
    }
    // -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
    // modifier tests ||||||||||||||||||||||
    // -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

    function testRevertIfCollateralZero() public {
        // Arrange
        vm.startPrank(USER);
        // We need to approve the LiraEngine to spend our WETH with the correct amount
        ERC20Mock(weth).approve(address(liraEngine), COLLATERAL_AMOUNT);
        // Act & Assert
        // Here we expect the revert to be thrown when we try to deposit zero collateral even though
        //we have approved the LiraEngine to spend our WETH
        vm.expectRevert(LiraEngine.liraEngine_greaterThanZero.selector);
        // Attempt to deposit zero collateral
        liraEngine.depositCollateral(weth, 0);
        vm.stopPrank();
    }

    function testRevertIfCollateralAddressIsNotAllowed() public {
        ERC20Mock fakeToken = new ERC20Mock();
        vm.startPrank(USER);
        vm.expectRevert(LiraEngine.liraEngine_tokenNotAllowed.selector);
        liraEngine.depositCollateral(address(fakeToken), COLLATERAL_AMOUNT);
        vm.stopPrank();
    }

    // -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
    // Event tests |||||||||||||||||||||||||||||||||||||||||
    // -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
    function testDepositCollateralEmitsEvent() public {
        // Arrange
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(liraEngine), COLLATERAL_AMOUNT);
        // Act
        vm.expectEmit(true, true, true, true);
        emit LiraEngine.CollateralDeposited(USER, weth, COLLATERAL_AMOUNT);
        liraEngine.depositCollateral(weth, COLLATERAL_AMOUNT);
        vm.stopPrank();
    }

    // function testCollateralRedeemedEmitsEvent() public {
    //     // Arrange
    //     vm.startPrank(USER);
    //     ERC20Mock(weth).approve(address(liraEngine), COLLATERAL_AMOUNT);
    //     liraEngine.depositCollateral(weth, COLLATERAL_AMOUNT);
    //     // Act & Assert
    //     vm.expectEmit(true, true, true, true);
    //     emit LiraEngine.CollateralRedeemed(USER, LIQUIDATOR, weth, COLLATERAL_AMOUNT / 2);
    //     liraEngine.redeemCollateral(weth, COLLATERAL_AMOUNT);
    //     vm.stopPrank();
    // }

    // -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
    // constructor tests ||||||||||||||||||||||
    // -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

    address[] public collateralAddresses;
    address[] public priceFeedAddresses;

    function testRevertIfCollateralAddressLengthDoesNotMatchPriceFeeds() public {
        // Arrange
        collateralAddresses.push(weth);
        priceFeedAddresses.push(wethPriceFeed);
        priceFeedAddresses.push(wbtcPriceFeed);
        // Act & Assert
        vm.expectRevert(LiraEngine.liraEngine_tokenAddressesAndpriceFeedAddressesMustBeSameLength.selector);
        // Attempt to deploy LiraEngine with mismatched lengths
        new LiraEngine(collateralAddresses, priceFeedAddresses, address(lira));
    }

    // -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
    // collateral tests||||||||||||||||||||||
    // -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

    function testDepositCollateral() public {
        // Arrange
        vm.startPrank(USER);
        // We need to approve the LiraEngine to spend our WETH with the correct amount
        ERC20Mock(weth).approve(address(liraEngine), COLLATERAL_AMOUNT);
        // Act
        liraEngine.depositCollateral(weth, COLLATERAL_AMOUNT);
        // Assert
        uint256 userCollateralBalance = liraEngine.getCollateralBalance(weth);
        assertEq(userCollateralBalance, COLLATERAL_AMOUNT, "User collateral balance should match deposited amount");
        vm.stopPrank();
    }

    function testGetCollateralBalance() public {
        // Arrange
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(liraEngine), COLLATERAL_AMOUNT);
        liraEngine.depositCollateral(weth, COLLATERAL_AMOUNT);
        // Act
        uint256 collateralBalance = liraEngine.getCollateralBalance(weth);
        // Assert
        assertEq(collateralBalance, COLLATERAL_AMOUNT, "Collateral balance should match deposited amount");
        vm.stopPrank();
    }

    function testgetCollateralPriceInUSD() public view {
        // Arrange
        uint256 amount = 1 ether; // 1 ETH in wei
        uint256 expectedUsdValue = 2000 * 10 ** 18; // Assuming 1 ETH = $2000
        // Act
        uint256 usdValue = liraEngine.getCollateralPriceInUSD(weth, amount);
        // Assert
        assertEq(usdValue, expectedUsdValue, "USD value should match expected value");
    }

    function testGetCollteralValueFromUsd() public view {
        // Arrange
        uint256 amountInUSD = 2000 * 10 ** 18; // $2000 in wei
        uint256 expectedCollateralValue = 1 ether; // Assuming 1 ETH = $2000
        // Act
        uint256 collateralValue = liraEngine.getCollateralPriceFromUsd(weth, amountInUSD);
        // Assert
        assertEq(collateralValue, expectedCollateralValue, "Collateral value should match expected value");
    }

    function testdepositCollateralForLira_Success() public {
        // Arrange
        vm.startPrank(USER);
        uint256 amountToDeposit = 3 ether; // 0.5 WETH
        uint256 amountToMint = 1 * 10 ** 18; // 100 Lira

        // Approve tokens for both deposits
        ERC20Mock(weth).approve(address(liraEngine), amountToDeposit);
        // Act
        liraEngine.depositCollateralForLira(weth, amountToDeposit, amountToMint);

        // Assert
        uint256 userLiraBalance = lira.balanceOf(USER);
        uint256 userCollateralBalance = liraEngine.getCollateralBalance(weth);
        assertEq(userLiraBalance, amountToMint, "LIRA tokens should be minted");
        // assertEq(userCollateralBalance, amountToDeposit, "Collateral should be deposited");

        // Verify health factor
        // uint256 healthFactor =
        //     liraEngine.calculateHealthFactor(amountToMint, liraEngine.getAllCollateralsValueInUSD(USER));
        // assertGe(healthFactor, MIN_HEALTH_FACTOR, "Health factor should be sufficient");

        vm.stopPrank();
    }

    // -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
    // liquidation tests||||||||||||||||||||||
    // -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

    // -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
    // Account info and Getter functions  tests||||||||||||||||||||||
    // -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
}
