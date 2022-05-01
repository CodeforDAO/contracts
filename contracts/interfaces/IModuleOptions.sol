//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IModuleOptions {
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

    function vestedAmount(uint256 memberId, uint64 timestamp)
        external
        view
        returns (uint256 _amount);

    function released(uint256 memberId) external returns (uint256);

    function scheduleOptions(uint256 memberId, VestingDetail calldata options)
        external
        returns (bytes32 _proposalId);

    function release() external;
}
