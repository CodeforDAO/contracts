//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'hardhat/console.sol';
import '@openzeppelin/contracts/governance/TimelockController.sol';

import '../interfaces/IMembership.sol';
import {DataTypes} from '../libraries/DataTypes.sol';

contract Treasury is TimelockController {
    address public membership;
    address public share;

    address[] private _proposers;
    address[] private _executors = [address(0)];
    DataTypes.DAOSettings private _initialSettings;

    constructor(address membershipTokenAddress, DataTypes.DAOSettings memory settings)
        TimelockController(settings.timelockDelay, _proposers, _executors)
    {
        membership = membershipTokenAddress;
        _initialSettings = settings;
    }

    modifier investmentEnabled() {
        require(_initialSettings.share.enableInvestment);
        _;
    }

    function invest() external payable investmentEnabled {}

    function investInERC20(address token_) external investmentEnabled {}
}
