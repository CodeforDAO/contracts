//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/governance/TimelockController.sol';

interface IModule {
    function NAME() external returns (string memory);

    function DESCRIPTION() external returns (string memory);

    function membership() external returns (address);

    function share() external returns (address);

    function timelock() external returns (TimelockController);

    function listOperators() external view returns (uint256[] memory);

    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description,
        bytes32 referId
    ) external returns (bytes32 id);

    function confirm(bytes32 id) external;

    function schedule(bytes32 id) external;

    function excute(bytes32 id) external;

    function cancel(bytes32 id) external;

    event ModuleProposalCreated(
        address indexed module,
        bytes32 indexed id,
        address indexed sender,
        uint256 timestamp
    );

    event ModuleProposalConfirmed(
        address indexed module,
        bytes32 indexed id,
        address indexed sender,
        uint256 timestamp
    );

    event ModuleProposalScheduled(
        address indexed module,
        bytes32 indexed id,
        address indexed sender,
        uint256 timestamp
    );

    event ModuleProposalExecuted(
        address indexed module,
        bytes32 indexed id,
        address indexed sender,
        uint256 timestamp
    );

    event ModuleProposalCancelled(
        address indexed module,
        bytes32 indexed id,
        address indexed sender,
        uint256 timestamp
    );
}
