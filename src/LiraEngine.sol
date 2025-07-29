// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Lira} from "./Lira.sol"; // Assuming Lira is the stablecoin contract
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {OracleLib} from "./library/OracleLib.sol"; // Importing the OracleLib for price feed checks

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
    // Error codes can be defined here ||||||||||||||||||||||||||||||||||||||||||||
    // -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
    /// @notice Error thrown when the amount is not greater than zero
    error liraEngine_greaterThanZero();
    /// @notice Error thrown when the token address is not allowed in the system
    error liraEngine_tokenNotAllowed();
    /// @notice Error thrown when the transfer of collateral tokens fails
    error liraEngine_depositCollateralTransferFaild();
    /// @notice Error thrown when the transfer of collateral tokens fails
    error liraEngine_tranferFaild();
    /// @notice Error thrown when the length of token addresses and price feed addresses do not match
    error liraEngine_tokenAddressesAndpriceFeedAddressesMustBeSameLength();
    /// @notice Error thrown when the health factor is too low
    error liraEngine_healthFactorTooLow(uint256 healthFactor);
    /// @notice Error thrown when minting fails
    error liraEngine_mintingFaild();
    /// @notice Error thrown when the amount exceeds the user's collateral balance
    error liraEngine_amountExceedsUserCollateral(uint256 amount);
    /// @notice Error thrown when the user tries to redeem collateral but the health factor is okay
    error liraEngine_healthFactorIsOkey();
    /// @notice Error thrown when the health factor is not improved after liquidation
    error liraEngine_healthFactorNotImproved();

    // -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
    // types can be defined here ||||||||||||||||||||||||||||||||||||||||||||
    // -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
    using OracleLib for AggregatorV3Interface;

    // -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
    // State variables, and mappings can be defined here ||||||||||||||||||||||||||||
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
    uint256 private constant MIN_HEALTH_FACTOR = 1e18; // Minimum health factor to avoid liquidation
    // -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
    // Event declarations can be defined here||||||||||||||||||||||||||||||||||||||||||
    // -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

    event CollateralDeposited(address indexed user, address indexed collateralAddress, uint256 amount);
    event CollateralRedeemed(
        address indexed from, address indexed to, address indexed collateralAddress, uint256 amount
    );
    // -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
    // modifiers can be defined here|||||||||||||||||||||||||||||||||||||||||||||||
    //=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
    /**
     * @notice This modifier checks if the amount is greater than zero.
     * @param amount The amount to be checked.
     * @dev If the amount is less than or equal to zero, it will revert with an error.
     */

    modifier isGreaterThanZero(uint256 amount) {
        if (amount <= 0) {
            revert liraEngine_greaterThanZero();
        }
        _;
    }
    // -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
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
    // contract constructor||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
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

    // -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
    // Collateral Functions||||||||||||||||||||||||||||||||||||||||||||||
    // -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
    //  depositCollateral() - User can deposit collateral (transfer collateral to the contract)
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
        public
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
    //  getCollateralBalance() - User can get the balance of a specific collateral token
    // -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
    /**
     * @notice This function retrieves the balance of a specific collateral token for a user.
     * @param collateralAddress The address of the collateral token.
     * @return The balance of the specified collateral token for the user.
     * @dev This function is used to get the balance of a specific collateral token for a user.
     */

    function getCollateralBalance(address collateralAddress) public view returns (uint256) {
        return s_collateralBalances[msg.sender][collateralAddress];
    }
    // getCollateralPriceInUSD - User can get the price of a specific collateral token in USD
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
        (, int256 price,,,) = priceFeedContract.staleCheckLatestRoundData();

        return ((uint256(price) * FEED_PRECISION) * amount) / USD_PRECISION; // Assuming price is in 8 decimals and amount is in 18 decimals
    }

    //  getCollateralPriceFromUsd() - User can get the price of a specific collateral token from USD
    // -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
    /**
     * @notice This function retrieves the price of a given collateral token from a specified USD amount.
     * @param collateralAddress The address of the collateral token.
     * @param usdAmount The amount in USD to convert to the collateral token's price.
     * @return The price of the collateral token in its native decimals.
     * @dev This function uses Chainlink price feeds to get the price of the collateral token.
     * It assumes that the price feed returns the price in 8 decimals and the amount is in 18 decimals.
     */
    function getCollateralPriceFromUsd(address collateralAddress, uint256 usdAmount) public view returns (uint256) {
        AggregatorV3Interface priceFeedContract = AggregatorV3Interface(s_priceFeeds[collateralAddress]);
        (, int256 price,,,) = priceFeedContract.staleCheckLatestRoundData();

        return ((usdAmount * USD_PRECISION) / (uint256(price) * FEED_PRECISION)); // Assuming price is in 8 decimals and amount is in 18 decimals
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

    // depositCollateralForLira() - User can deposit collateral for lira (transfer collateral to the contract and mint lira)
    // -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
    /**
     * @notice This function allows users to deposit collateral and mint Lira tokens.
     * @param collateralAddress The address of the collateral token to be deposited.
     * @param collateralAmount The amount of the collateral token to be deposited.
     * @param amountToMint The amount of Lira tokens to mint.
     * @dev This function is used to deposit collateral into the Lira system and mint Lira tokens for the caller.
     * It checks if the user has enough collateral before proceeding with the deposit and minting.
     */
    function depositCollateralForLira(address collateralAddress, uint256 collateralAmount, uint256 amountToMint)
        external
        isGreaterThanZero(collateralAmount)
        isGreaterThanZero(amountToMint)
        isCollateralAddressAllowed(collateralAddress)
    {
        // Deposit collateral
        depositCollateral(collateralAddress, collateralAmount);
        // Mint Lira tokens
        mintLira(amountToMint);
    }
    // _redeemCollateral() - Internal function to redeem collateral
    // -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
    /**
     * @notice This function redeems collateral for a user.
     * @param collateralAddress The address of the collateral token to be redeemed.
     * @param amount The amount of the collateral token to be redeemed.
     * @param from The address from which the collateral is being redeemed.
     * @param to The address to which the collateral is being transferred.
     * @dev This function is used internally to redeem collateral from the Lira system.
     * It updates the user's collateral balance and transfers the collateral back to the user.
     */

    function _redeemCollateral(address collateralAddress, uint256 amount, address from, address to)
        private
        isGreaterThanZero(amount)
        isCollateralAddressAllowed(collateralAddress)
    {
        if (amount > s_collateralBalances[from][collateralAddress]) {
            revert liraEngine_amountExceedsUserCollateral(amount);
        }
        // Update the user's collateral balance
        s_collateralBalances[from][collateralAddress] -= amount;
        emit CollateralRedeemed(from, to, collateralAddress, amount);
        // Transfer the collateral back to the user
        bool success = IERC20(collateralAddress).transfer(to, amount);
        if (!success) {
            revert liraEngine_tranferFaild();
        }
    }

    //  redeemCollateral() - User can redeem collateral (transfer collateral back to the user)
    // -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
    /**
     * @notice This function allows users to redeem their collateral.
     * @param collateralAddress The address of the collateral token to be redeemed.
     * @param amount The amount of the collateral token to be redeemed.
     * @dev This function is used to redeem collateral from the Lira system.
     * It checks if the user has enough collateral before proceeding with the redemption.
     */
    function redeemCollateral(address collateralAddress, uint256 amount)
        public
        isGreaterThanZero(amount)
        isCollateralAddressAllowed(collateralAddress)
        nonReentrant
    {
        _redeemCollateral(collateralAddress, amount, msg.sender, msg.sender);
        _revertIfHealthFactorIsKaput(msg.sender);
    }

    // redeemCollateralForLira() - User can redeem collateral for Lira (transfer collateral back to the user and burn lira)
    // -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
    /**
     * @notice This function allows users to redeem collateral for Lira tokens.
     * @param collateralAddress The address of the collateral token to be redeemed.
     * @param amount The amount of the collateral token to be redeemed.
     * @param amountToBurn The amount of Lira tokens to burn.
     * @dev This function is used to redeem collateral from the Lira system and burn the corresponding Lira tokens.
     * It checks if the user has enough collateral before proceeding with the redemption.
     */
    function redeemCollateralForLira(address collateralAddress, uint256 amount, uint256 amountToBurn)
        external
        isGreaterThanZero(amount)
        isCollateralAddressAllowed(collateralAddress)
        nonReentrant
    {
        burnLira(amountToBurn);
        redeemCollateral(collateralAddress, amount);
    }

    // -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
    // Liqusidation Functions ||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
    // -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
    // 1. liquidate() - User can liquidate collateral (liquidate collateral if the health factor is too low)
    // -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

    /**
     * @notice This function allows users to liquidate collateral if the health factor is too low.
     * @param collateralAddress The address of the collateral token to be liquidated.
     * @param user The address of the user whose collateral is being liquidated.
     * @param debtToCover The amount of debt to cover through liquidation.
     * @dev This function is used to liquidate collateral from a user's account if their health factor is below a certain threshold.
     * It checks if the debt to cover is greater than zero and if the collateral address is allowed before proceeding with liquidation.
     */
    function liquidate(address collateralAddress, address user, uint256 debtToCover)
        external
        isGreaterThanZero(debtToCover)
        isCollateralAddressAllowed(collateralAddress)
        nonReentrant
    {
        uint256 startingUserHealthFactor = _healthFactor(user);
        if (startingUserHealthFactor >= MIN_HEALTH_FACTOR) {
            revert liraEngine_healthFactorIsOkey();
        }
        uint256 collateralAmountFromDebtCovered = getCollateralPriceFromUsd(collateralAddress, debtToCover);
        uint256 bonusCollateralAmount = (collateralAmountFromDebtCovered * 10) / 100; // 10% bonus
        uint256 totalCollateralAmountTobeRedeemed = collateralAmountFromDebtCovered + bonusCollateralAmount;
        _redeemCollateral(collateralAddress, totalCollateralAmountTobeRedeemed, user, msg.sender);
        _burnLira(debtToCover, user, msg.sender);
        uint256 endingUserHealthFactor = _healthFactor(user);
        if (endingUserHealthFactor <= startingUserHealthFactor) {
            revert liraEngine_healthFactorNotImproved();
        }
        _revertIfHealthFactorIsKaput(msg.sender);
    }

    // -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
    // Minting Functions||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
    // -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

    // getLiraMinted() - User can get the total amount of lira minted
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
    //  mintLira() - User can borrow stable coins (mint lira against the collateral)
    // -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
    function mintLira(uint256 amountToMint) public isGreaterThanZero(amountToMint) nonReentrant {
        s_liraMinted[msg.sender] += amountToMint;
        _revertIfHealthFactorIsKaput(msg.sender);
        bool minted = i_liraToken.mint(msg.sender, amountToMint);
        if (!minted) {
            revert liraEngine_mintingFaild();
        }
    }
    // getLiraMinted() - User can get the total amount of lira minted
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
    // -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
    // Lira Burnig Functions |||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
    // -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

    // burnLira() - User can burn lira (burn lira to reduce the amount of lira minted)
    // -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
    /**
     * @notice This function allows users to burn Lira tokens.
     * @param amountToBurn The amount of Lira tokens to burn.
     * @dev This function is used to burn Lira tokens for the caller.
     * It is designed to be called by users who want to reduce their minted Lira tokens.
     * It checks that the amount is greater than zero before proceeding.
     */
    function burnLira(uint256 amountToBurn) public isGreaterThanZero(amountToBurn) nonReentrant {
        s_liraMinted[msg.sender] -= amountToBurn;
        bool success = i_liraToken.transferFrom(msg.sender, address(this), amountToBurn);
        if (!success) {
            revert liraEngine_tranferFaild();
        }
        i_liraToken.burn(amountToBurn);
    }

    // _burnLira() - Internal function to burn Lira tokens
    // -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
    /**
     * @notice This function burns Lira tokens from a specified address.
     * @param amountToBurn The amount of Lira tokens to burn.
     * @param onBehalf The address on whose behalf the tokens are being burned.
     * @param liraFrom The address from which the tokens are being transferred before burning.
     * @dev This function is used to burn Lira tokens from a specified address.
     * It checks that the amount is greater than zero before proceeding.
     */
    function _burnLira(uint256 amountToBurn, address onBehalf, address liraFrom)
        private
        isGreaterThanZero(amountToBurn)
        nonReentrant
    {
        s_liraMinted[onBehalf] -= amountToBurn;
        bool success = i_liraToken.transferFrom(liraFrom, address(this), amountToBurn);
        if (!success) {
            revert liraEngine_tranferFaild();
        }
        i_liraToken.burn(amountToBurn);
    }
    // -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
    // Account info functions|||||||||||||||||||||||||||||||||||||||||||||
    // -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
    // getAccountInfo() - User can get account info (total collateral value and total lira minted)
    //-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
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

    // getAccountInformation() - User can get account information (total collateral value and total lira minted)
    // -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
    /**
     * @notice This function retrieves account information for a user, including total collateral value and total Lira minted.
     * @param user The address of the user whose account information is being queried.
     * @return totalDscMinted The total amount of Lira minted by the user.
     * @return collateralValueInUsd The total value of the user's collateral in USD.
     * @dev This function is used to get the account information for a specific user.
     */
    function getAccountInformation(address user)
        public
        view
        returns (uint256 totalDscMinted, uint256 collateralValueInUsd)
    {
        return _getAccountInfo(user);
    }
    // -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
    //  HealthFactor functions|||||||||||||||||||||||||||||||||||||||||||||
    // -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
    // _healthFactor() - Internal function to calculate the health factor of a user
    // -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
    /**
     * @notice This function calculates the health factor for a user based on their total Lira minted and total collateral value in USD.
     * @param user The address of the user whose health factor is being calculated.
     * @return The health factor of the user.
     * @dev This function is used internally to calculate the health factor for a specific user.
     */

    function _healthFactor(address user) private view returns (uint256) {
        (uint256 totalLiraMinted, uint256 totalCollateralValueInUSD) = _getAccountInfo(user);
        return _calculateHealthFactor(totalLiraMinted, totalCollateralValueInUSD);
    }

    // _calculateHealthFactor() - Internal function to calculate the health factor based on total Lira minted and collateral value in USD
    // -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
    /**
     * @notice This function calculates the health factor based on the total Lira minted and the collateral value in USD.
     * @param totalDscMinted The total amount of Lira minted by the user.
     * @param collateralValueInUsd The total value of the user's collateral in USD.
     * @return The calculated health factor.
     * @dev This function is used internally to calculate the health factor for a specific user.
     */
    function _calculateHealthFactor(uint256 totalDscMinted, uint256 collateralValueInUsd)
        internal
        pure
        returns (uint256)
    {
        if (totalDscMinted == 0) return type(uint256).max;
        uint256 collateralAdjustedForThreshold = (collateralValueInUsd * LIQUIDATION_LIMI) / LIQUIDATION_PRECENTAGE;
        return (collateralAdjustedForThreshold * USD_PRECISION) / totalDscMinted;
    }
    // calculateHealthFactor() - User can calculate the health factor based on total Lira minted and collateral value in USD
    // -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
    /**
     * @notice This function calculates the health factor based on the total Lira minted and collateral value in USD.
     * @param totalDscMinted The total amount of Lira minted by the user.
     * @param collateralValueInUsd The total value of the user's collateral in USD.
     * @return The calculated health factor.
     * @dev This function is used to calculate the health factor for a specific user.
     */

    function calculateHealthFactor(uint256 totalDscMinted, uint256 collateralValueInUsd)
        external
        pure
        returns (uint256)
    {
        return _calculateHealthFactor(totalDscMinted, collateralValueInUsd);
    }

    // _revertIfHealthFactorIsKaput() - Internal function to check if the health factor is below a certain threshold
    // -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
    /**
     * @notice This function checks if the health factor of a user is below the minimum threshold.
     * @param user The address of the user whose health factor is being checked.
     * @dev This function is used internally to ensure that the user's health factor is above the minimum threshold.
     * If the health factor is below the minimum, it will revert with an error.
     */
    function _revertIfHealthFactorIsKaput(address user) private view {
        uint256 healthFactor = _healthFactor(user);
        if (healthFactor < MIN_HEALTH_FACTOR) {
            revert liraEngine_healthFactorTooLow(healthFactor);
        }
    }
    // -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
    //  Getter functions|||||||||||||||||||||||||||||||||||||||||||||
    // -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

    function getCollateralAddresses() public view returns (address[] memory) {
        return s_collateralAddresses;
    }

    function getCollateralBalance(address user, address collateralAddress) public view returns (uint256) {
        return s_collateralBalances[user][collateralAddress];
    }

    function getCollateralTokenPriceFeed(address collateral) external view returns (address) {
        return s_priceFeeds[collateral];
    }
}
