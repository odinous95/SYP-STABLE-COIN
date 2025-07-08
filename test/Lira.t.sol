// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {Lira} from "../src/Lira.sol";

contract LiraTest is Test {
    Lira lira;

    function setUp() public {
        lira = new Lira();
    }
}
