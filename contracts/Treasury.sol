//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/governance/TimelockController.sol";

import "./interface/IMembership.sol";

contract Treasury is 
  TimelockController {
  address public Membership;

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
  }

  function invest() external payable {
  }
}