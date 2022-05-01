//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IModulePayroll} from './IModulePayroll.sol';

interface IModuleOKR {
    struct OKRDetail {
        bytes description;
        IModulePayroll.PayrollDetail reward;
    }

    struct OKRKeys {
        uint256 memberId;
        uint64 year;
        uint64 quarter;
    }

    event OKRAdded(uint256 indexed memberId, OKRDetail okr);
    event OKRScheduled(uint256 indexed memberId, bytes32 proposalId);
    event RewardExecuted(address indexed account, uint256 indexed memberId, uint256 amount);

    function addOKR(
        uint64 year,
        uint64 quarter,
        bytes calldata description,
        IModulePayroll.PayrollDetail calldata reward
    ) external;

    function scheduleOKR(
        uint256 memberId,
        uint64 year,
        uint64 quarter
    ) external returns (bytes32 _proposalId);
}
