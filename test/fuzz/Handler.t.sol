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
    uint256 constant MAX_COLLATERAL = type(uint96).max;
    address[] public usersDepositors;

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
        amountOfCollaterals = bound(amountOfCollaterals, 1, MAX_COLLATERAL);
        vm.startPrank(msg.sender);
        narrowedCollateral.mint(msg.sender, amountOfCollaterals);
        narrowedCollateral.approve(address(liraEngine), amountOfCollaterals);
        liraEngine.depositCollateral(address(narrowedCollateral), amountOfCollaterals);
        vm.stopPrank();
        // Record the user who deposited collateral
        usersDepositors.push(msg.sender);
    }

    function redeemCollateral(uint256 randomNum, uint256 amountOfCollaterals) public {
        ERC20Mock narrowedCollateral = _getAllowedCollaterals(randomNum);
        uint256 maxCollateralDeposited = liraEngine.getCollateralBalance(msg.sender, address(narrowedCollateral));
        amountOfCollaterals = bound(amountOfCollaterals, 0, maxCollateralDeposited);
        if (amountOfCollaterals == 0) {
            return;
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

    function mintLira(uint256 amount, uint256 randomNum) public {
        if (usersDepositors.length == 0) {
            return;
        }
        address sender = usersDepositors[randomNum % usersDepositors.length];
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = liraEngine.getAccountInformation(sender);
        uint256 maxLiraMintable = (collateralValueInUsd / 2) - totalDscMinted;
        if (maxLiraMintable < 0) {
            return;
        }
        amount = bound(amount, 1, uint256(maxLiraMintable));
        if (amount == 0) {
            return;
        }
        vm.startPrank(sender);
        liraEngine.mintLira(amount);
        vm.stopPrank();
    }
}
