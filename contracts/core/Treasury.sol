//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'hardhat/console.sol';
import '@openzeppelin/contracts/governance/TimelockController.sol';

import '../interfaces/IMembership.sol';
import {DataTypes} from '../libraries/DataTypes.sol';

contract Treasury is TimelockController {
    address public Membership;
    DataTypes.DAOSettings public initialSettings;

    constructor(
        uint256 minDelay,
        address[] memory proposers,
        address[] memory executors,
        address membership,
        DataTypes.DAOSettings memory settings
    ) TimelockController(minDelay, proposers, executors) {
        Membership = membership;
        initialSettings = settings;
    }

    modifier investmentEnabled() {
        require(_enableInvestment);
        _;
    }

    function invest() external payable investmentEnabled {}

    function investInERC20(address token_) external investmentEnabled {}
}
