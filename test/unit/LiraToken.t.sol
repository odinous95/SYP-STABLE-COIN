// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import {Lira} from "../../src/Lira.sol";

contract LiraTest is Test {
    Lira private lira;
    address private owner;
    address private user;

    function setUp() public {
        owner = address(this); // This test contract is the owner
        user = address(0xBEEF);
        lira = new Lira(); // Deploy the Lira contract
    }

    // -=-=-= initial state -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-= //
    function testInitialState() public view {
        assertEq(lira.name(), "Lira Stable");
        assertEq(lira.symbol(), "LIRA");
        assertEq(lira.decimals(), 18);
        assertEq(lira.totalSupply(), 0);
        assertEq(lira.balanceOf(owner), 0);
    }

    // -=-=-= mint tests -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-= //
    function testMintTokens() public {
        uint256 mintAmount = 1_000 ether;

        // Call mint as the owner (this contract)
        bool success = lira.mint(user, mintAmount);

        assertTrue(success, "Mint should return true");
        assertEq(lira.balanceOf(user), mintAmount);
    }

    function test_Revert_MintToZeroAddress() public {
        vm.expectRevert("lira_addressZeroNotAllowed()");
        lira.mint(address(0), 1000); // Should revert
    }

    // -=-=-= burn tests -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-= //

    function testBurnTokens() public {
        uint256 mintAmount = 1_000 ether;
        lira.mint(address(this), mintAmount); // owner mints to themselves
        lira.burn(mintAmount); // owner burns their tokens
        assertEq(lira.balanceOf(address(this)), 0);
    }
}
