// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Lira} from "./Lira.sol"; // Assuming Lira is the stablecoin contract
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

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
// State variables, and mappings can be defined here
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

uint256 private constant FEED_PRECISION = 1e10;
    uint256 private constant USD_PRECISION = 1e18;

// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
// Event declarations can be defined here
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
event CollateralDeposited(address indexed user, address indexed collateralAddress, uint256 amount);

// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
// modifiers can be defined here
//=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
modifier isGreaterThanZero(uint256 amount) {
        if (amount <= 0) {
            revert liraEngine_greaterThanZero(amount);
        }
        _;
    }

    modifier isCollateralAddressAllowed(address tokenAddress) {
        if (s_priceFeeds[tokenAddress] == address(0)) {
            // If the token is not in the price feed mapping, it is not allowed
            revert liraEngine_tokenNotAllowed();
        }
        _;
    }

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

    /**
     * @notice This function allows users to deposit collateral into the Lira system.
     * @notice CEI - Checks, Effects, Interactions
     * @param collateralAddress The address of the token to be deposited as collateral.
     * @param amount The amount of the token to be deposited.
     * @dev This function is used to deposit collateral into the Lira system.
     * It accepts the address of the token and the amount to be deposited.
     * It is designed to be called by users who want to provide collateral
     */
    function depositCollateral(address collateralAddress, uint256 amount)
        external
        isGreaterThanZero(amount)
        isCollateralAddressAllowed(collateralAddress)
        nonReentrant
    {
        s_collateralBalances[msg.sender][collateralAddress] += amount;
        // Emit an event for the deposit (optional)
        emit CollateralDeposited(msg.sender, collateralAddress, amount);
        // Transfer the tokens from the user to the contract
        bool success = IERC20(collateralAddress).transferFrom(msg.sender, address(this), amount);
        if (!success) {
            revert liraEngine_depositCollateralTransferFaild();
        }
    }

// =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
    /**
     * @notice This function retrieves the price of a given collateral token in USD.
     * @param collateralAddress The address of the collateral token.
     * @param amount The amount of the collateral token.
     * @return priceInUSD The price of the collateral token in USD.
     * @dev This function uses Chainlink price feeds to get the price of the collateral token.
     * It assumes that the price feed returns the price in 8 decimals and the amount is in 18 decimals.
     */
    function getCollateralPriceInUSD(address collateralAddress, uint256 amount) private view returns (uint256) {
        AggregatorV3Interface priceFeedContract = AggregatorV3Interface(s_priceFeeds[collateralAddress]);
        (, int256 price,,,) = priceFeedContract.latestRoundData();

        return ((uint256(price) * FEED_PRECISION) * amount) / USD_PRECISION; // Assuming price is in 8 decimals and amount is in 18 decimals
    }

    // -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
    /**
     * @notice This function allows users to get the total collateral value in USD.
     * @param user The address of the user whose collateral value is being queried.
     * @return totalCollateralValue The total value of the user's collateral in USD.
     * @dev This function calculates the total value of all collateral held by a user in USD.
     * It iterates through the user's collateral balances and sums up the values based on the price feeds.
     */
    function getAllCollateralsValueInUSD(address user) public view returns (uint256) {
        uint256 totalCollateralValue = 0;
        // Iterate through the user's collateral balances
        for (uint256 i = 0; i < s_collateralAddresses.length; i++) {
            address collateralAddress = s_collateralAddresses[i];
            uint256 collateralAmount = s_collateralBalances[user][collateralAddress];
            if (collateralAmount > 0) {
                // Assuming getPriceInUSD is a function that returns the price of the token in USD
                uint256 priceInUSD = getCollateralPriceInUSD(s_priceFeeds[collateralAddress], collateralAmount);
                totalCollateralValue += collateralAmount * priceInUSD;
            }
        }
        return totalCollateralValue;
    }

// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
// Here we define the functions we want to define for the the engine.
// 1.depositCollater() User can deposit collateral (transfer collateral to the contract)
// 2.withDrawCollateral() User can withdraw collateral for stable coins (burn lira against the collateral)
// 3.mint() User can borrow stable coins (mint lira again the collateral)
// 4.liguidate() liquidation function for the collateral when the collateral value is less than the stable coin value
// 5 getHealthFactor() function to get the health factor of the collateral
}
