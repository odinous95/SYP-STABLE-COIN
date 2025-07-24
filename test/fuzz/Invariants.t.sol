// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
// what are the invariants of the system?
// 1. The total supply of the stablecoin should always less than the total value of the underlying assets(collateral).
// 2. getter functions should always return the correct values and never revert.

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {DeployLiraEngine} from "../../script/DeployLira.s.sol";
import {LiraEngine} from "../../src/LiraEngine.sol";
import {Lira} from "../../src/Lira.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {console} from "forge-std/console.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Handler} from "./Handler.t.sol";

contract InvariantsTest is StdInvariant, Test {
    DeployLiraEngine deployer;
    LiraEngine liraEngine;
    HelperConfig helperConfig;
    Lira lira;
    Handler handler;
    address weth;
    address wbtc;

    function setUp() external {
        deployer = new DeployLiraEngine();
        (lira, liraEngine, helperConfig) = deployer.run();
        (,, address wethAddress, address wbtcAddress,) = helperConfig.activeChainConfig();
        weth = wethAddress;
        wbtc = wbtcAddress;
        handler = new Handler(liraEngine, lira);
        // Set the target contract for invariants, which is the Handler contract
        targetContract(address(handler));
    }

    function invariant_totalSupplyLessThanCollateral() public view {
        uint256 totalSupply = lira.totalSupply();
        uint256 totalWethDepposited = IERC20(weth).balanceOf(address(liraEngine));
        uint256 totalWbtcDepposited = IERC20(wbtc).balanceOf(address(liraEngine));
        uint256 allCollateralValueInUsd = liraEngine.getCollateralPriceInUSD(weth, totalWethDepposited)
            + liraEngine.getCollateralPriceInUSD(wbtc, totalWbtcDepposited);
        assert(totalSupply <= allCollateralValueInUsd);
    }

    function invariant_getterFunctionsReturnCorrectValues() public view {
        liraEngine.getCollateralAddresses();
        liraEngine.getCollateralBalance(address(this), weth);
        liraEngine.getCollateralBalance(address(this), wbtc);
    }
}
