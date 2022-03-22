//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IModule {
    function NAME() external returns (string memory);

    function DESCRIPTION() external returns (string memory);

    function membership() external returns (address);

    function share() external returns (address);

    function timelock() external returns (address);

    function listOperators() external view returns (uint256[] memory);

    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) external returns (bytes32 id);

    function confirm(bytes32 id) external;

    function schedule(bytes32 id) external;

    function excute(bytes32 id) external;

    function cancel(bytes32 id) external;
}
