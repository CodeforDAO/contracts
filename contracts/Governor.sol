//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/governance/Governor.sol";
import "@openzeppelin/contracts/governance/compatibility/GovernorCompatibilityBravo.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorSettings.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorVotes.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorVotesQuorumFraction.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorTimelockControl.sol";

import "./Treasury.sol";

contract MembershipGovernor is 
  Governor, 
  GovernorSettings,
  GovernorCompatibilityBravo,
  GovernorVotes, 
  GovernorVotesQuorumFraction, 
  GovernorTimelockControl
{
  address[] public GovernorProposers = [address(this)];
  address[] public GovernorExecutors = [address(this)];

  constructor(
    string memory name_,
    IVotes token_,
    uint256 votingDelay_,
    uint256 votingPeriod_,
    uint256 proposalThreshold_,
    uint256 quorumNumerator_
  ) 
    Governor(name_)
    GovernorSettings(votingDelay_, votingPeriod_, proposalThreshold_)
    GovernorVotes(token_)
    GovernorVotesQuorumFraction(quorumNumerator_)
    GovernorTimelockControl(new Treasury(votingDelay_, GovernorProposers, GovernorExecutors))
  {}

  // The functions below are overrides required by Solidity.
  function quorum(uint256 blockNumber)
    public
    view
    override(IGovernor, GovernorVotesQuorumFraction)
    returns (uint256)
  {
    return super.quorum(blockNumber);
  }

  function getVotes(address account, uint256 blockNumber)
    public
    view
    override(IGovernor, GovernorVotes)
    returns (uint256)
  {
    return super.getVotes(account, blockNumber);
  }

  function state(uint256 proposalId)
      public
      view
      override(Governor, IGovernor, GovernorTimelockControl)
      returns (ProposalState)
  {
      return super.state(proposalId);
  }

  function proposalThreshold() public view override(Governor, GovernorSettings) returns (uint256) {
      return super.proposalThreshold();
  }

  function propose(address[] memory targets, uint256[] memory values, bytes[] memory calldatas, string memory description)
    public
    override(Governor, GovernorCompatibilityBravo, IGovernor)
    returns (uint256)
  {
    return super.propose(targets, values, calldatas, description);
  }

  function _execute(uint256 proposalId, address[] memory targets, uint256[] memory values, bytes[] memory calldatas, bytes32 descriptionHash)
    internal
    override(Governor, GovernorTimelockControl)
  {
    super._execute(proposalId, targets, values, calldatas, descriptionHash);
  }

  function _cancel(address[] memory targets, uint256[] memory values, bytes[] memory calldatas, bytes32 descriptionHash)
    internal
    override(Governor, GovernorTimelockControl)
    returns (uint256)
  {
    return super._cancel(targets, values, calldatas, descriptionHash);
  }

  function _executor()
    internal
    view
    override(Governor, GovernorTimelockControl)
    returns (address)
  {
    return super._executor();
  }

  function supportsInterface(bytes4 interfaceId)
    public
    view
    override(Governor, IERC165, GovernorTimelockControl)
    returns (bool)
  {
    return super.supportsInterface(interfaceId);
  }
}