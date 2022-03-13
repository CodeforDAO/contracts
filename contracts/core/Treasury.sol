//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'hardhat/console.sol';
import '@openzeppelin/contracts/governance/TimelockController.sol';

import '../interfaces/IMembership.sol';
import {DataTypes} from '../libraries/DataTypes.sol';

contract Treasury is TimelockController {
    address public share;
    address public membership;
    DataTypes.InvestmentSettings public investmentSettings;

    address[] private _proposers;
    address[] private _executors = [address(0)];

    constructor(
        DataTypes.DAOSettings memory settings,
        address membershipTokenAddress,
        address shareTokenAddress
    ) TimelockController(settings.timelockDelay, _proposers, _executors) {
        membership = membershipTokenAddress;
        share = shareTokenAddress;
        investmentSettings = settings.investment;
    }

    modifier investmentEnabled() {
        require(investmentSettings.enableInvestment);
        _;
    }

    function updateInvestmentSettings(DataTypes.InvestmentSettings memory settings) public {
        require(msg.sender == address(this), 'TimelockController: caller must be timelock');

        investmentSettings = settings;
    }

    function invest() external payable investmentEnabled {}

    function investInERC20(address token_) external investmentEnabled {}
}
