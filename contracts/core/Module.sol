//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'hardhat/console.sol';
import '@openzeppelin/contracts/governance/TimelockController.sol';
import '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';
import '@openzeppelin/contracts/utils/Context.sol';

import {IMembership} from '../interfaces/IMembership.sol';
import {Errors} from '../libraries/Errors.sol';
import {Events} from '../libraries/Events.sol';
import {DataTypes} from '../libraries/DataTypes.sol';

// Module core is basically a mutiple-sign contract with a timelock
abstract contract Module is Context {
    using EnumerableSet for EnumerableSet.UintSet;

    string public NAME;
    string public DESCRIPTION;
    address public immutable membership;
    TimelockController public immutable timelock;
    mapping(bytes32 => mapping(uint256 => bool)) public isConfirmed;

    address[] private _proposers = [address(this)];
    address[] private _executors = [address(this)];
    EnumerableSet.UintSet private _operators;
    mapping(bytes32 => DataTypes.MicroProposal) private _proposals;

    constructor(
        string memory name,
        string memory description,
        address membershipTokenAddress,
        uint256[] memory operators,
        uint256 timelockDelay
    ) {
        NAME = name;
        DESCRIPTION = description;
        membership = membershipTokenAddress;
        timelock = new TimelockController(timelockDelay, _proposers, _executors);
        _updateOperators(operators);
    }

    modifier onlyOperator() {
        if (!_operators.contains(getMembershipTokenId())) revert Errors.NotOperator();
        _;
    }

    function propose(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata calldatas,
        string calldata description
    ) public virtual onlyOperator returns (bytes32 id) {
        bytes32 _id = timelock.hashOperationBatch(
            targets,
            values,
            calldatas,
            0,
            keccak256(bytes(description))
        );
        _proposals[_id] = DataTypes.MicroProposal(
            DataTypes.ProposalStatus.Pending,
            0,
            targets,
            values,
            calldatas,
            description
        );

        emit Events.ModuleProposalCreated(address(this), _id, _msgSender(), block.timestamp);

        return _id;
    }

    function confirm(bytes32 id) public virtual onlyOperator {
        if (_proposals[id].status != DataTypes.ProposalStatus.Pending)
            revert Errors.InvalidProposalStatus();

        _proposals[id].confirmations++;
        isConfirmed[id][getMembershipTokenId()] = true;
        emit Events.ModuleProposalConfirmed(address(this), id, _msgSender(), block.timestamp);
    }

    function schedule(bytes32 id) public virtual onlyOperator {
        DataTypes.MicroProposal memory _proposal = _proposals[id];

        if (_proposal.status != DataTypes.ProposalStatus.Pending)
            revert Errors.InvalidProposalStatus();

        if (_proposal.confirmations < _operators.length()) revert Errors.NotEnoughConfirmations();

        timelock.scheduleBatch(
            _proposal.targets,
            _proposal.values,
            _proposal.calldatas,
            0,
            keccak256(bytes(_proposal.description)),
            timelock.getMinDelay()
        );

        _proposal.status = DataTypes.ProposalStatus.Scheduled;

        emit Events.ModuleProposalScheduled(address(this), id, _msgSender(), block.timestamp);
    }

    function excute(bytes32 id) public virtual onlyOperator {
        DataTypes.MicroProposal memory _proposal = _proposals[id];

        if (_proposal.status != DataTypes.ProposalStatus.Scheduled)
            revert Errors.InvalidProposalStatus();

        timelock.executeBatch(
            _proposal.targets,
            _proposal.values,
            _proposal.calldatas,
            0,
            keccak256(bytes(_proposal.description))
        );

        _proposal.status = DataTypes.ProposalStatus.Executed;

        emit Events.ModuleProposalExecuted(address(this), id, _msgSender(), block.timestamp);
    }

    function cancel(bytes32 id) public virtual onlyOperator {
        DataTypes.MicroProposal memory _proposal = _proposals[id];
        if (_proposal.status != DataTypes.ProposalStatus.Executed)
            revert Errors.InvalidProposalStatus();

        if (_proposal.status == DataTypes.ProposalStatus.Scheduled) {
            timelock.cancel(id);
        }

        emit Events.ModuleProposalCancelled(address(this), id, _msgSender(), block.timestamp);
        delete _proposals[id];
    }

    function listOperators() public view virtual returns (uint256[] memory) {
        return _operators.values();
    }

    function getMembershipTokenId() internal view returns (uint256) {
        return IMembership(membership).tokenOfOwnerByIndex(_msgSender(), 0);
    }

    function _updateOperators(uint256[] memory operators_) private {
        for (uint256 i = 0; i < operators_.length; i++) {
            _operators.add(operators_[i]);
        }
    }
}
