// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {LiraEngine} from "../../src/LiraEngine.sol";
import {Lira} from "../../src/Lira.sol";

contract Handler is Test {
    LiraEngine liraEngine;
    Lira lira;

    constructor(LiraEngine _liraEngine, Lira _lira) {
        liraEngine = _liraEngine;
        lira = _lira;
    }

    function depositCollateral(address collateralAddress, uint256 ammoundCollateral) public {
        liraEngine.depositCollateral(collateralAddress, ammoundCollateral);
    }
}
