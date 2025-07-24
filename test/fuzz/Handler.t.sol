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

    /**
     * @notice Deposits collateral into the contract for the sender.
     * @dev Updates the sender's collateral balance and emits a Deposit event.
     * @param amountOfCollaterals The amount of collateral to deposit.
     * @param randomNum A random number to determine which collateral to use.
     * @dev The random number is used to select between WETH and WBTC.
     * @dev The amount of collaterals is bounded between 1 and MAX_COLLATERAL.
     */
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
    /**
     * @notice Redeems collateral from the contract for the sender.
     * @dev Updates the sender's collateral balance and emits a Redeem event.
     * @param randomNum A random number to determine which collateral to use.
     * @param amountOfCollaterals The amount of collateral to redeem.
     * @dev The random number is used to select between WETH and WBTC.
     * @dev The amount of collaterals is bounded between 0 and the maximum deposited collateral.
     */

    function redeemCollateral(uint256 randomNum, uint256 amountOfCollaterals) public {
        ERC20Mock narrowedCollateral = _getAllowedCollaterals(randomNum);
        uint256 maxCollateralDeposited = liraEngine.getCollateralBalance(msg.sender, address(narrowedCollateral));
        amountOfCollaterals = bound(amountOfCollaterals, 0, maxCollateralDeposited);
        if (amountOfCollaterals == 0) {
            return;
        }
        liraEngine.redeemCollateral(address(narrowedCollateral), amountOfCollaterals);
    }

    /**
     * @notice Returns the allowed collateral based on a random number.
     * @param randomNum A random number to determine which collateral to return.
     * @return ERC20Mock The selected collateral token (WETH or WBTC).
     * @dev This function uses the random number to select between WETH and WBTC.
     */
    function _getAllowedCollaterals(uint256 randomNum) private view returns (ERC20Mock) {
        if (randomNum % 2 == 0) {
            return weth;
        } else {
            return wbtc;
        }
    }

    /**
     * @notice Mints Lira tokens for the sender based on their collateral value.
     * @param amount The amount of Lira to mint.
     * @param randomNum A random number to select a user from the depositors.
     * @dev The amount is bounded between 1 and the maximum mintable Lira based on collateral.
     */
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
