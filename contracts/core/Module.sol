//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'hardhat/console.sol';
import '@openzeppelin/contracts/governance/TimelockController.sol';
import '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';
import '@openzeppelin/contracts/utils/Context.sol';

import {IMembership} from '../interfaces/IMembership.sol';
import {ITreasury} from '../interfaces/ITreasury.sol';
import {IModule} from '../interfaces/IModule.sol';
import {Errors} from '../libraries/Errors.sol';
import {DataTypes} from '../libraries/DataTypes.sol';

/**
 * @title Core Module
 * @notice The core module consists of a multi-signature contract and a time lock.
 * The application module can authorize and pull assets from the vault by inheriting this core module.
 */
abstract contract Module is Context, IModule {
    using EnumerableSet for EnumerableSet.UintSet;

    string public NAME;
    string public DESCRIPTION;
    address public immutable membership;
    address public immutable share;
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
        share = IMembership(membershipTokenAddress).shareToken();
        timelock = new TimelockController(timelockDelay, _proposers, _executors);
        _updateOperators(operators);
    }

    modifier onlyOperator() {
        if (!_operators.contains(getMembershipTokenId(_msgSender()))) revert Errors.NotOperator();
        _;
    }

    modifier onlyTimelock() {
        if (_msgSender() != address(timelock)) revert Errors.NotTimelock();
        _;
    }

    // @dev Shortcut view methods designed for inherited submodules.
    function listOperators() public view virtual returns (uint256[] memory) {
        return _operators.values();
    }

    function getMembershipTokenId(address account) internal view returns (uint256) {
        return IMembership(membership).tokenOfOwnerByIndex(account, 0);
    }

    function getAddressByMemberId(uint256 tokenId) internal view returns (address) {
        return IMembership(membership).ownerOf(tokenId);
    }

    function getProposal(bytes32 id) internal view returns (DataTypes.MicroProposal memory) {
        return _proposals[id];
    }

    /**
     * @dev Pull payments
     * Pull available payments from DAO's treasury contract,
     * to this module's timelock contract
     */
    function pullPayments(
        uint256 eth,
        address[] memory tokens,
        uint256[] memory amounts
    ) internal virtual {
        bool nothingToPull = eth == 0 && tokens.length == 0 && amounts.length == 0;

        if (!nothingToPull) {
            ITreasury(IMembership(membership).treasury()).pullModulePayment(eth, tokens, amounts);
        }
    }

    /**
     * @dev Propose MicroProposal
     * Propose a micro-proposal, Use the same algorithm as timelock for hash id
     */
    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description,
        bytes32 referId
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
            description,
            referId
        );

        emit ModuleProposalCreated(address(this), _id, _msgSender(), block.timestamp);

        return _id;
    }

    /**
     * @dev Confirm MicroProposal
     * Confirm a micro-proposal
     */
    function confirm(bytes32 id) public virtual onlyOperator {
        if (_proposals[id].status != DataTypes.ProposalStatus.Pending)
            revert Errors.InvalidProposalStatus();

        uint256 _tokenId = getMembershipTokenId(_msgSender());

        if (isConfirmed[id][_tokenId]) revert Errors.AlreadyConfirmed();

        _proposals[id].confirmations++;
        isConfirmed[id][_tokenId] = true;

        emit ModuleProposalConfirmed(address(this), id, _msgSender(), block.timestamp);
    }

    /**
     * @dev Schedule MicroProposal
     * schedule a micro-proposal, Requires confirmation from all operators
     */
    function schedule(bytes32 id) public virtual onlyOperator {
        DataTypes.MicroProposal memory _proposal = _proposals[id];

        if (_proposal.status != DataTypes.ProposalStatus.Pending)
            revert Errors.InvalidProposalStatus();

        if (_proposal.confirmations < _operators.length()) revert Errors.NotEnoughConfirmations();

        _beforeSchedule(id, _proposal.referId);

        timelock.scheduleBatch(
            _proposal.targets,
            _proposal.values,
            _proposal.calldatas,
            0,
            keccak256(bytes(_proposal.description)),
            timelock.getMinDelay()
        );

        _afterSchedule(id, _proposal.referId);

        _proposals[id].status = DataTypes.ProposalStatus.Scheduled;

        emit ModuleProposalScheduled(address(this), id, _msgSender(), block.timestamp);
    }

    /**
     * @dev Excute MicroProposal
     * excute a micro-proposal, execution can be allowed when the period set by the timelock has expired.
     * The executor must be the operator.
     */
    function excute(bytes32 id) public virtual onlyOperator {
        DataTypes.MicroProposal memory _proposal = _proposals[id];

        if (_proposal.status != DataTypes.ProposalStatus.Scheduled)
            revert Errors.InvalidProposalStatus();

        _beforeExcute(id, _proposal.referId);

        timelock.executeBatch(
            _proposal.targets,
            _proposal.values,
            _proposal.calldatas,
            0,
            keccak256(bytes(_proposal.description))
        );

        _proposals[id].status = DataTypes.ProposalStatus.Executed;

        emit ModuleProposalExecuted(address(this), id, _msgSender(), block.timestamp);
    }

    /**
     * @dev Cancel MicroProposal
     * cancel a micro-proposal, It is not possible to cancel a proposal that has already been executed.
     * If the proposal is scheduled by the timelock, call the cancel method of the timelock.
     */
    function cancel(bytes32 id) public virtual onlyOperator {
        DataTypes.MicroProposal memory _proposal = _proposals[id];
        if (_proposal.status != DataTypes.ProposalStatus.Executed)
            revert Errors.InvalidProposalStatus();

        if (_proposal.status == DataTypes.ProposalStatus.Scheduled) {
            timelock.cancel(id);
        }

        emit ModuleProposalCancelled(address(this), id, _msgSender(), block.timestamp);
        delete _proposals[id];
    }

    function _beforeExcute(bytes32 id, bytes32 referId) internal virtual {}

    function _beforeSchedule(bytes32 id, bytes32 referId) internal virtual {}

    function _afterSchedule(bytes32 id, bytes32 referId) internal virtual {}

    function _updateOperators(uint256[] memory operators_) private {
        for (uint256 i = 0; i < operators_.length; i++) {
            _operators.add(operators_[i]);
        }
    }
}
