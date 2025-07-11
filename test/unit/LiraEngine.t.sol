// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {LiraEngine} from "../../src/LiraEngine.sol";
import {Lira} from "../../src/Lira.sol";
import {DeployLiraEngine} from "../../script/DeployLira.s.sol";

contract LiraEngineTest is Test {
    DeployLiraEngine deployer;
    LiraEngine engine;
    Lira lira;

    function setUp() public {
        deployer = new DeployLiraEngine();
        (lira, engine) = deployer.run();
    }
}
