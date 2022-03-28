//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'hardhat/console.sol';
import '@openzeppelin/contracts/utils/Strings.sol';
import '@openzeppelin/contracts/utils/Address.sol';

import {Module} from '../core/Module.sol';
import {IMembership} from '../interfaces/IMembership.sol';
import {IShare} from '../interfaces/IShare.sol';
import {Errors} from '../libraries/Errors.sol';

/**
 * @title Options Module
 * @notice The Options module provides DAO members with the ability to grant options.
 */
contract Options is Module {
    using Strings for uint256;

    struct VestingDetail {
        uint256 amount;
        uint64 startAt;
        uint64 duration;
    }

    struct VestingKeys {
        uint256 memberId;
        uint256 index;
    }

    event OptionsAdded(uint256 indexed memberId, VestingDetail options);
    event OptionsScheduled(uint256 indexed memberId, bytes32 proposalId);
    event OptionsReleased(uint256 indexed memberId, uint256 amount);

    error NoOptions();

    mapping(uint256 => VestingDetail[]) private _options;
    mapping(bytes32 => VestingKeys) private _optionsKeys;
    mapping(uint256 => uint256) private _released;

    constructor(
        address membership,
        uint256[] memory operators,
        uint256 delay
    ) Module('Options', 'Options Module V1', membership, operators, delay) {}

    function released(uint256 memberId) public view virtual returns (uint256) {
        return _released[memberId];
    }

    /**
     * @dev Schedule Options
     * Schedule a member's compensation proposal to the compensation cycle
     */
    function scheduleOptions(uint256 memberId, VestingDetail calldata options)
        public
        onlyOperator
        returns (bytes32 _proposalId)
    {
        address[] memory targets;
        uint256[] memory values;
        bytes[] memory calldatas;
        string memory description = string(
            abi.encodePacked(
                options.amount,
                ' Options for #',
                memberId.toString(),
                '@',
                block.timestamp.toString()
            )
        );

        targets[0] = address(this);
        values[0] = 0;

        // TODO: use byte4(func selector) to reduce the size of calldata
        calldatas[0] = abi.encodeWithSignature(
            'addVestingPlan(uint256,uint256,uint64,uint64)',
            memberId,
            options.amount,
            options.startAt,
            options.duration
        );

        bytes32 _referId = keccak256(abi.encode(memberId));
        _optionsKeys[_referId] = VestingKeys(memberId, 0);
        _proposalId = propose(targets, values, calldatas, description, _referId);

        emit OptionsScheduled(memberId, _proposalId);
    }

    function addVestingPlan(
        uint256 memberId,
        uint256 amount,
        uint64 startAt,
        uint64 duration
    ) external payable onlyTimelock {
        uint256 _balance = IShare(share).balanceOf(address(this));

        if (_balance < amount) {
            address[] memory tokens = new address[](1);
            uint256[] memory amounts = new uint256[](1);
            tokens[0] = share;
            amounts[0] = amount - _balance;
            pullPayments(0, tokens, amounts);
        }

        VestingDetail memory vesting = VestingDetail(amount, startAt, duration);
        _options[memberId].push(vesting);
        emit OptionsAdded(memberId, vesting);
    }

    function release() public {
        if (IMembership(membership).balanceOf(_msgSender()) == 0) revert Errors.NotMember();

        uint256 memberId = getMembershipTokenId(_msgSender());

        if (_options[memberId].length == 0) revert NoOptions();

        uint256 releasable = vestedAmount(memberId, uint64(block.timestamp)) - released(memberId);

        _released[memberId] += releasable;
        emit OptionsReleased(memberId, releasable);

        IShare(share).transfer(_msgSender(), releasable);
    }

    function vestedAmount(uint256 memberId, uint64 timestamp)
        public
        view
        returns (uint256 _amount)
    {
        uint256 _balance = IShare(share).balanceOf(address(this));

        for (uint256 i = 0; i < _options[memberId].length; i++) {
            _amount += _vestingSchedule(
                _options[memberId][i],
                _balance + released(memberId),
                timestamp
            );
        }
    }

    function _vestingSchedule(
        VestingDetail memory options,
        uint256 totalAllocation,
        uint64 timestamp
    ) private pure returns (uint256) {
        if (timestamp < options.startAt) {
            return 0;
        } else if (timestamp > options.startAt + options.duration) {
            return totalAllocation;
        } else {
            return (totalAllocation * (timestamp - options.startAt)) / options.duration;
        }
    }
}
