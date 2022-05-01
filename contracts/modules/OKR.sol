//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'hardhat/console.sol';
import '@openzeppelin/contracts/utils/Strings.sol';
import '@openzeppelin/contracts/utils/Address.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {Module} from '../core/Module.sol';
import {IModulePayroll} from '../interfaces/IModulePayroll.sol';
import {IModuleOKR} from '../interfaces/IModuleOKR.sol';

/**
 * @title OKR Module
 * @notice This module is designed to allow all members of the DAO to set their own OKRs and receive predetermined shares or compensation rewards based on the achievement of the corresponding goals.
 */
contract OKR is Module, IModuleOKR {
    using Strings for uint256;
    using Address for address payable;

    // MemberId => (YEAR => OKRDetail[])
    mapping(uint256 => mapping(uint64 => OKRDetail[])) private _OKRs;
    mapping(bytes32 => OKRKeys) private _OKRIds;

    constructor(
        address membership,
        uint256[] memory operators,
        uint256 delay
    ) Module('OKR', 'OKR Module V1', membership, operators, delay) {}

    /**
     * @dev Add OKR
     * Add an OKR for the signer
     */
    function addOKR(
        uint64 year,
        uint64 quarter,
        bytes calldata description,
        IModulePayroll.PayrollDetail calldata reward
    ) external {
        uint256 memberId = getMembershipTokenId(_msgSender());
        OKRDetail memory okr = OKRDetail(description, reward);
        _OKRs[memberId][year][quarter] = okr;
        emit OKRAdded(memberId, okr);
    }

    /**
     * @dev Schedule OKR
     * Adding a member's compensation proposal to the compensation cycle
     */
    function scheduleOKR(
        uint256 memberId,
        uint64 year,
        uint64 quarter
    ) public onlyOperator returns (bytes32 _proposalId) {
        OKRDetail memory okr = _OKRs[memberId][year][quarter];
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        string memory description = string(
            abi.encodePacked(
                year,
                ' ',
                quarter,
                ' OKR for #',
                memberId.toString(),
                '@',
                block.timestamp.toString()
            )
        );

        address memberWallet = getAddressByMemberId(memberId);

        targets[0] = address(this);
        values[0] = okr.reward.amount;

        // TODO: use byte4(func selector) to reduce the size of calldata
        calldatas[0] = abi.encodeWithSignature(
            'execTransfer(uint256,address,address[],uint256[])',
            memberId,
            memberWallet,
            okr.reward.tokens.addresses,
            okr.reward.tokens.amounts
        );

        bytes32 _referId = keccak256(abi.encode(memberId, year, quarter));
        _OKRIds[_referId] = OKRKeys(memberId, year, quarter);
        _proposalId = propose(targets, values, calldatas, description, _referId);

        emit OKRScheduled(memberId, _proposalId);
    }

    function _beforeExecute(bytes32 id, bytes32 referId) internal virtual override {
        super._beforeExecute(id, referId);

        OKRKeys memory _keys = _OKRIds[referId];
        OKRDetail memory okr = _OKRs[_keys.memberId][_keys.year][_keys.quarter];
        uint256 _eth;
        uint256 _balance = address(timelock).balance;
        address[] memory _tokens;
        uint256[] memory _amounts;

        _eth += okr.reward.amount;

        pullPayments(_balance < _eth ? _eth - _balance : 0, _tokens, _amounts);
    }

    /**
     * @dev Exec Transfer
     * Hook method for okr proposals
     */
    function execTransfer(
        uint256 memberId,
        address payable account,
        address[] calldata tokens,
        uint256[] calldata amounts
    ) external payable onlyTimelock {
        if (msg.value > 0) {
            account.sendValue(msg.value);
        }

        for (uint256 i = 0; i < tokens.length; i++) {
            if (IERC20(tokens[i]).balanceOf(address(timelock)) >= amounts[i]) {
                IERC20(tokens[i]).transferFrom(address(timelock), address(account), amounts[i]);
            }
        }

        emit RewardExecuted(account, memberId, msg.value);
    }
}
