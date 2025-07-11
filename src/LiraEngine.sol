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
    /// @notice Error thrown when the amount is not greater than zero
    error liraEngine_greaterThanZero(uint256 amount);
    /// @notice Error thrown when the token address is not allowed in the system
    error liraEngine_tokenNotAllowed();
    /// @notice Error thrown when the transfer of collateral tokens fails
    error liraEngine_depositCollateralTransferFaild();
    /// @notice Error thrown when the length of token addresses and price feed addresses do not match
    error liraEngine_tokenAddressesAndpriceFeedAddressesMustBeSameLength();
    /// @notice Error thrown when the health factor is too low
    error liraEngine_healthFactorTooLow(uint256 healthFactor);
    /// @notice Error thrown when minting fails
    error liraEngine_mintingFaild();

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

    uint256 private constant FEED_PRECISION = 1e10; // 1 Lira = 1 USD, so we use 10 decimals for price feeds
    uint256 private constant USD_PRECISION = 1e18; // 1 Lira = 1 USD, so we use 18 decimals for USD and 10 for price feeds
    uint256 private constant LIQUIDATION_LIMI = 50; // 50% liquidation limit
    uint256 private constant LIQUIDATION_PRECENTAGE = 100; // 100% liquidation limit
    uint256 private constant MIN_HEALTH_FACTOR = 1; // Minimum health factor to avoid liquidation
    // -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
    // Event declarations can be defined here
    // -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

    event CollateralDeposited(address indexed user, address indexed collateralAddress, uint256 amount);

    // -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
    // modifiers can be defined here
    //=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

    /**
     * @notice This modifier checks if the amount is greater than zero.
     * @param amount The amount to be checked.
     * @dev If the amount is less than or equal to zero, it will revert with an error.
     */
    modifier isGreaterThanZero(uint256 amount) {
        if (amount <= 0) {
            revert liraEngine_greaterThanZero(amount);
        }
        _;
    }

    /**
     * @notice This modifier checks if the collateral address is allowed in the system.
     * @param tokenAddress The address of the token to be checked.
     * @dev If the token address is not in the price feed mapping, it will revert with an error.
     */
    modifier isCollateralAddressAllowed(address tokenAddress) {
        if (s_priceFeeds[tokenAddress] == address(0)) {
            // If the token is not in the price feed mapping, it is not allowed
            revert liraEngine_tokenNotAllowed();
        }
        _;
    }

    // -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
    // contract constructor||||||||||||||||||||||||||||||||||||||||||
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

    // Collateral Functions||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
    // 1. depositCollateral() - User can deposit collateral (transfer collateral to the contract)
    // -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
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
    // 2. getCollateralBalance() - User can get the balance of a specific collateral token
    // -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
    // 3. getCollateralPriceInUSD - User can get the price of a specific collateral token in USD
    // -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
    /**
     * @notice This function retrieves the price of a given collateral token in USD.
     * @param collateralAddress The address of the collateral token.
     * @param amount The amount of the collateral token.
     * @return priceInUSD The price of the collateral token in USD.
     * @dev This function uses Chainlink price feeds to get the price of the collateral token.
     * It assumes that the price feed returns the price in 8 decimals and the amount is in 18 decimals.
     * after we deposit the collateral, we can get the price of the collateral in USD
     */

    function getCollateralPriceInUSD(address collateralAddress, uint256 amount) public view returns (uint256) {
        AggregatorV3Interface priceFeedContract = AggregatorV3Interface(s_priceFeeds[collateralAddress]);
        (, int256 price,,,) = priceFeedContract.latestRoundData();

        return ((uint256(price) * FEED_PRECISION) * amount) / USD_PRECISION; // Assuming price is in 8 decimals and amount is in 18 decimals
    }

    // 4. getAllCollateralsValueInUSD() - User can get the total value of all collaterals in USD
    // -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
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

    // Minting Functions||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
    // 1. mintLira() - User can borrow stable coins (mint lira against the collateral)
    // -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
    /**
     * @notice This function allows users to mint Lira tokens.
     * @param amountToMint The amount of Lira tokens to mint.
     * @dev This function is used to mint Lira tokens for the caller.
     * It is designed to be called by users who want to mint Lira tokens.
     * It must have more collateral than the amount of Lira tokens they want to mint.
     * It checks that the amount is greater than zero before proceeding.
     *
     */
    function mintLira(uint256 amountToMint) external isGreaterThanZero(amountToMint) nonReentrant {
        s_liraMinted[msg.sender] += amountToMint;
        _revertIfHealthFactorIsKaput(msg.sender);
        bool minted = i_liraToken.mint(msg.sender, amountToMint);
        if (!minted) {
            revert liraEngine_mintingFaild();
        }
    }
    // 2. getLiraMinted() - User can get the total amount of lira minted
    // -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
    /**
     * @notice This function retrieves the total amount of Lira tokens minted by a user.
     * @param user The address of the user whose minted Lira tokens are being queried.
     * @return The total amount of Lira tokens minted by the user.
     * @dev This function is used to get the total amount of Lira tokens minted by a specific user.
     */

    function _getLiraMinted(address user) private view returns (uint256) {
        return s_liraMinted[user];
    }

    // Account info functions and HealthFactor||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
    // 1.getAccountInfo() - User can get account info (total collateral value and total lira minted)
    // -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
    /**
     * @notice This function retrieves account information for a user, including total collateral value and total Lira minted.
     * @param user The address of the user whose health factor is being queried.
     * @dev This function calculates the health factor based on the total collateral value and total Lira minted by the user.
     */
    function _getAccountInfo(address user)
        private
        view
        returns (uint256 totalCollateralValueInUSD, uint256 totalLiraMinted)
    {
        totalLiraMinted = _getLiraMinted(user);
        totalCollateralValueInUSD = getAllCollateralsValueInUSD(user);
        return (totalLiraMinted, totalCollateralValueInUSD);
    }

    function _healthFactor(address user) private view returns (uint256) {
        (uint256 totalLiraMinted, uint256 totalCollateralValueInUSD) = _getAccountInfo(user);
        uint256 collateralAdjustedForLiquidation = totalCollateralValueInUSD * LIQUIDATION_LIMI / LIQUIDATION_PRECENTAGE; // Adjust collateral value for liquidation limit
        return (collateralAdjustedForLiquidation * USD_PRECISION) / totalLiraMinted; // Health factor calculation
    }
    // 2. _revertIfHealthFactorIsKaput() - Internal function to check if the health factor is below a certain threshold

    function _revertIfHealthFactorIsKaput(address user) private view {
        uint256 healthFactor = _healthFactor(user);
        if (healthFactor < MIN_HEALTH_FACTOR) {
            revert liraEngine_healthFactorTooLow(healthFactor);
        }
    }
}
