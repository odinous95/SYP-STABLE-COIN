// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {LiraEngine} from "../../src/LiraEngine.sol";
import {Lira} from "../../src/Lira.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract Handler is Test {
    LiraEngine liraEngine;
    Lira lira;
    ERC20Mock weth;
    ERC20Mock wbtc;

    constructor(LiraEngine _liraEngine, Lira _lira) {
        liraEngine = _liraEngine;
        lira = _lira;
        address[] memory collateralAddresses = liraEngine.getCollateralAddresses();
        weth = ERC20Mock(collateralAddresses[0]);
        wbtc = ERC20Mock(collateralAddresses[1]);
    }

    // let's narrow down the function for only the avalible collateralAddress

    function depositCollateral(uint256 randomNum, uint256 amountOfCollaterals) public {
        ERC20Mock narrowedCollateral = _getAllowedCollaterals(randomNum);
        amountOfCollaterals = bound(amountOfCollaterals, 1, 1100);
        vm.startPrank(msg.sender);
        narrowedCollateral.mint(msg.sender, amountOfCollaterals);
        narrowedCollateral.approve(address(liraEngine), amountOfCollaterals);
        liraEngine.depositCollateral(address(narrowedCollateral), amountOfCollaterals);
        vm.stopPrank();
    }

    function redeemCollateral(uint256 randomNum, uint256 amountOfCollaterals) public {
        ERC20Mock narrowedCollateral = _getAllowedCollaterals(randomNum);
        uint256 maxCollateralDeposited = liraEngine.getCollateralsBalace(msg.sender, address(narrowedCollateral));
        amountOfCollaterals = bound(amountOfCollaterals, 0, maxCollateralDeposited);
        if (maxCollateralDeposited == 0) {
            return; // No collateral to redeem
        }
        liraEngine.redeemCollateral(address(narrowedCollateral), amountOfCollaterals);
    }

    function _getAllowedCollaterals(uint256 randomNum) private view returns (ERC20Mock) {
        if (randomNum % 2 == 0) {
            return weth;
        } else {
            return wbtc;
        }
    }
}
