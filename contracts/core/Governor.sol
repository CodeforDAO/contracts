//SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

// import 'hardhat/console.sol';
import '@openzeppelin/contracts/governance/Governor.sol';
import '@openzeppelin/contracts/governance/compatibility/GovernorCompatibilityBravo.sol';
import '@openzeppelin/contracts/governance/extensions/GovernorSettings.sol';
import '@openzeppelin/contracts/governance/extensions/GovernorVotes.sol';
import '@openzeppelin/contracts/governance/extensions/GovernorVotesQuorumFraction.sol';
import '@openzeppelin/contracts/governance/extensions/GovernorTimelockControl.sol';

import {Treasury} from './Treasury.sol';
import {Errors} from '../libraries/Errors.sol';
import {DataTypes} from '../libraries/DataTypes.sol';

/**
 * @title Treasury Governor
 * @notice A governance contract is basically a contract that allows voting using any token contract that inherits the `IVotes` interface.
 * It has a default setting that does not allow external accounts that do not hold voting tokens to vote,
 * to reduce state storage and security risks.
 */
contract TreasuryGovernor is
    Governor,
    GovernorSettings,
    GovernorCompatibilityBravo,
    GovernorVotes,
    GovernorVotesQuorumFraction,
    GovernorTimelockControl
{
    constructor(
        string memory name,
        address token,
        Treasury treasury,
        DataTypes.GovernorSettings memory settings
    )
        Governor(name)
        GovernorSettings(settings.votingDelay, settings.votingPeriod, settings.proposalThreshold)
        GovernorVotes(IVotes(token))
        GovernorVotesQuorumFraction(settings.quorumNumerator)
        GovernorTimelockControl(treasury)
    {}

    // @dev Block voting from msg.sender has 0 vote token
    function _castVote(
        uint256 proposalId,
        address account,
        uint8 support,
        string memory reason
    ) internal override returns (uint256) {
        if (getVotes(msg.sender, block.number - 1) < proposalThreshold())
            revert Errors.VotesBelowProposalThreshold();

        return super._castVote(proposalId, account, support, reason);
    }

    // @dev The functions below are overrides required by Solidity.
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
        override(Governor, IGovernor)
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

    function proposalThreshold()
        public
        view
        override(Governor, GovernorSettings)
        returns (uint256)
    {
        return super.proposalThreshold();
    }

    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) public override(Governor, GovernorCompatibilityBravo, IGovernor) returns (uint256) {
        return super.propose(targets, values, calldatas, description);
    }

    function _execute(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) {
        super._execute(proposalId, targets, values, calldatas, descriptionHash);
    }

    function _cancel(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) returns (uint256) {
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
