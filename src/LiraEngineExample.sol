// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {Lira} from "./Lira.sol"; // Assuming LiraToken is defined in this file
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol"; // Assuming Chainlink price feed interface is used
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
    error liraEngine_tokenAddressesAndpriceFeedAddressesMustBeSameLength();
    error liraEngine_depositCollateralTransferFaild();

    // -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
    // State variables, mappings, and events can be defined here
    // -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
    uint256 private constant FEED_PRECISION = 1e10;
    uint256 private constant USD_PRECISION = 1e18;
    mapping(address collateralAddress => address priceFeed) private s_priceFeeds;

    mapping(address user => mapping(address collateralAddress => uint256 amount)) private s_collateralBalances;

    mapping(address user => uint256 amountLiraMinted) private s_liraMinted;

    address[] private s_collateralAddresses;

    Lira private immutable i_liraToken;

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

    constructor(address[] memory collateralAddresses, address[] memory priceFeedAddresses, address liraTokenAddress) {
        if (collateralAddresses.length != priceFeedAddresses.length) {
            revert liraEngine_tokenAddressesAndpriceFeedAddressesMustBeSameLength();
        }
        for (uint256 i = 0; i < collateralAddresses.length; i++) {
            s_priceFeeds[collateralAddresses[i]] = priceFeedAddresses[i];
            s_collateralAddresses.push(collateralAddresses[i]);
        }

        i_liraToken = Lira(liraTokenAddress);

        // Initialize the contract with any necessary setup
        // This can include setting up price feeds, allowed tokens, etc.
    }
    // -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
    // -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
    // Functions can be defined here
    // -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
    /**
     * @notice This function allows users to deposit collateral into the Lira system.
     * @notice CEI - Checks, Effects, Interactions
     * @param tokenAddress The address of the token to be deposited as collateral.
     * @param amount The amount of the token to be deposited.
     * @dev This function is used to deposit collateral into the Lira system.
     * It accepts the address of the token and the amount to be deposited.
     * It is designed to be called by users who want to provide collateral
     */

    function depositCollateral(address tokenAddress, uint256 amount)
        external
        isGreaterThanZero(amount)
        isCollateralAddressAllowed(tokenAddress)
        nonReentrant
    {
        s_collateralBalances[msg.sender][tokenAddress] += amount;
        // Emit an event for the deposit (optional)
        emit CollateralDeposited(msg.sender, tokenAddress, amount);
        // Transfer the tokens from the user to the contract
        bool success = IERC20(tokenAddress).transferFrom(msg.sender, address(this), amount);
        if (!success) {
            revert liraEngine_depositCollateralTransferFaild();
        }
    }

    // -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

    /**
     * @notice This function retrieves the price of a given collateral token in USD.
     * @param collateralAddress The address of the collateral token.
     * @param amount The amount of the collateral token.
     * @return priceInUSD The price of the collateral token in USD.
     * @dev This function uses Chainlink price feeds to get the price of the collateral token.
     * It assumes that the price feed returns the price in 8 decimals and the amount is in 18 decimals.
     */
    function getPriceInUSD(address collateralAddress, uint256 amount) private view returns (uint256) {
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
    function getCollateralValueInUSD(address user) public view returns (uint256) {
        uint256 totalCollateralValue = 0;
        // Iterate through the user's collateral balances
        for (uint256 i = 0; i < s_collateralAddresses.length; i++) {
            address collateralAddress = s_collateralAddresses[i];
            uint256 collateralAmount = s_collateralBalances[user][collateralAddress];
            if (collateralAmount > 0) {
                // Assuming getPriceInUSD is a function that returns the price of the token in USD
                uint256 priceInUSD = getPriceInUSD(s_priceFeeds[collateralAddress], collateralAmount);
                totalCollateralValue += collateralAmount * priceInUSD;
            }
        }
        return totalCollateralValue;
    }

    // -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
    /**
     * @notice This function allows users to mint Lira tokens.
     * @param amountTomint The amount of Lira tokens to mint.
     * @dev This function is used to mint Lira tokens for the caller.
     * It is designed to be called by users who want to mint Lira tokens.
     * It must have more collateral than the amount of Lira tokens they want to mint.
     * It checks that the amount is greater than zero before proceeding.
     *
     */
    function mintLira(uint256 amountTomint) external isGreaterThanZero(amountTomint) nonReentrant {
        s_liraMinted[msg.sender] += amountTomint;
        // they have minted more than they have collateral
        // _revertIfHealthFactorIsKaput(msg.sender);
    }

    // -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

    /**
     * @notice This function retrieves the total amount of Lira tokens minted by a user.
     * @param user The address of the user whose minted Lira tokens are being queried.
     * @return The total amount of Lira tokens minted by the user.
     * @dev This function is used to get the total amount of Lira tokens minted by a specific user.
     */
    function getLiraMinted(address user) private view returns (uint256) {
        return s_liraMinted[user];
    }

    // -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

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
        totalLiraMinted = getLiraMinted(user);
        totalCollateralValueInUSD = getCollateralValueInUSD(user);
        return (totalLiraMinted, totalCollateralValueInUSD);
    }

    // function _healthFactor(address user) private view returns (uint256) {
    //     // 1. Get the total collateral value of the user

    //     // 2. Get the total Lira minted by the user
    //     // 3. Calculate the health factor as totalCollateralValue / totalLiraMinted
    //     // 4. Return the health factor
    //     return 0; // Placeholder return value
    // }

    // function _revertIfHealthFactorIsKaput(address user) internal view {
    //     // 1. Get the total collateral value of the user
    //     // revert if the user has no collateral
    // }
}
