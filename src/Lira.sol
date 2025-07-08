// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {ERC20Burnable, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

///@title Lira Stable Token
///@notice A stable token contract that allows minting and burning of tokens.
///@dev This contract extends OpenZeppelin's ERC20Burnable and Ownable contracts.

contract Lira is ERC20Burnable, Ownable {
    // Custom errors -=-=-=-=-==- -=-=-=-=-==- -=-=-=-=-==- -=-=-=-=-==- -=-=-=-=-==-
    error lira_amoutMustBeGreaterThanZero();
    error lira_BurnAmountMoreThanBalance();
    error lira_addressZeroNotAllowed();

    constructor() ERC20("Lira Stable", "LIRA") Ownable(msg.sender) {}

    /// @notice Burns a specific amount of tokens from the caller's account.
    /// @dev Reduces the total supply and the caller's balance by the specified amount.
    /// Emits a {Transfer} event with the `to` address set to the zero address.
    /// Requirements:
    /// - The caller must have at least `amount` tokens.
    /// @param amount The number of tokens to burn from the caller's account.

    function burn(uint256 amount) public override onlyOwner {
        uint256 balance = balanceOf(msg.sender);
        if (amount <= 0) {
            revert lira_amoutMustBeGreaterThanZero();
        }
        if (balance < amount) {
            revert lira_BurnAmountMoreThanBalance();
        }
        super.burn(amount);
    }

    /// @notice Mints new tokens and assigns them to the specified address.
    /// @dev Increases the total supply and the balance of the specified address by the given amount.
    /// Emits a {Transfer} event with the `from` address set to the zero address.
    /// Requirements:
    /// - The `to` address must not be the zero address.
    /// - The `amount` must be greater than zero.
    /// @param to The address to which the newly minted tokens will be assigned.
    /// @param amount The number of tokens to mint.
    /// @return A boolean value indicating whether the minting was successful.

    function mint(address to, uint256 amount) public onlyOwner returns (bool) {
        if (to == address(0)) {
            revert lira_addressZeroNotAllowed();
        }
        if (amount <= 0) {
            revert lira_amoutMustBeGreaterThanZero();
        }
        _mint(to, amount);
        return true;
    }
}
