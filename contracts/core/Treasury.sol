//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'hardhat/console.sol';
import '@openzeppelin/contracts/governance/TimelockController.sol';

import '../interfaces/IMembership.sol';

contract Treasury is TimelockController {
    address public Membership;
    bool public _enableInvestment;

    constructor(
        uint256 minDelay,
        address[] memory proposers,
        address[] memory executors,
        bool enableInvestment,
        uint256 investThresholdInETH,
        address[] memory investInERC20,
        uint256[] memory investThresholdInERC20,
        address membership
    ) TimelockController(minDelay, proposers, executors) {
        Membership = membership;
        _enableInvestment = enableInvestment;
    }

    modifier investmentEnabled() {
        require(_enableInvestment);
        _;
    }

    function invest() external payable investmentEnabled {}

    function investInERC20(address token_) external investmentEnabled {}
}
