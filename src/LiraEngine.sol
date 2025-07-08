// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Lira} from "./Lira.sol"; // Assuming Lira is the stablecoin contract

/**
 *  @title Lira Engine
 *  @author Odi
 *  @notice This contract serves as the engine for the Lira stablecoin system.
 *  @dev It is designed to manage the core functionalities of the Lira stablecoin,
 * 1 lira is pegged to 1 USD.
 * including minting, burning, and transferring tokens.
 */

contract LiraEngine is ReentrancyGuard {
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
// Error codes can be defined here
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
error liraEngine_greaterThanZero(uint256 amount);
    error liraEngine_tokenNotAllowed();
    error liraEngine_depositCollateralTransferFaild();
    error liraEngine_tokenAddressesAndpriceFeedAddressesMustBeSameLength();

// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
// State variables, mappings, and events can be defined here
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
// Mapping to store the price feeds for each collateral address
    mapping(address collateralAddress => address priceFeed) private s_priceFeeds;
    // Mapping to store the collateral balances of each user
    mapping(address user => mapping(address collateralAddress => uint256 amount)) private s_collateralBalances;
    // Mapping to store the amount of Lira minted by each user
    mapping(address user => uint256 amountLiraMinted) private s_liraMinted;

    // Addresses of collateral tokens allowed in the system
    address[] private s_collateralAddresses;

    // Instance of the Lira stablecoin contract
    Lira private immutable i_liraToken;

// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
// Event declarations can be defined here
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
event CollateralDeposited(address indexed user, address indexed collateralAddress, uint256 amount);

// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
// modifiers can be defined here
//=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
// contract constructor
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

    /**
     * @notice Constructor to initialize the Lira Engine with collateral addresses and their corresponding price feeds.
     * @param collateralAddresses An array of addresses representing the collateral tokens allowed in the system.
     * @param priceFeedAddresses An array of addresses representing the price feeds for each collateral token.
     * @param liraTokenAddress The address of the Lira stablecoin contract.
     */
    constructor(address[] memory collateralAddresses, address[] memory priceFeedAddresses, address liraTokenAddress) {
        if (collateralAddresses.length != priceFeedAddresses.length) {
            revert liraEngine_tokenAddressesAndpriceFeedAddressesMustBeSameLength();
        }
        for (uint256 i = 0; i < collateralAddresses.length; i++) {
            s_priceFeeds[collateralAddresses[i]] = priceFeedAddresses[i];
            s_collateralAddresses.push(collateralAddresses[i]);
        }
        i_liraToken = Lira(liraTokenAddress);
    }
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
// Main Functions for the engine can be defined here
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
// Here we define the functions we want to define for the the engine.
// 1.depositCollater() User can deposit collateral (transfer collateral to the contract)
// 2.withDrawCollateral() User can withdraw collateral for stable coins (burn lira against the collateral)
// 3.mint() User can borrow stable coins (mint lira again the collateral)
// 4.liguidate() liquidation function for the collateral when the collateral value is less than the stable coin value
// 5 getHealthFactor() function to get the health factor of the collateral
}
