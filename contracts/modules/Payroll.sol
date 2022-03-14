//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'hardhat/console.sol';
import {Module} from '../core/Module.sol';

contract Payroll is Module {
    constructor(
        address membership,
        uint256[] memory operators,
        uint256 delay
    ) Module('Payroll', 'Payroll', membership, operators, delay) {}
}
