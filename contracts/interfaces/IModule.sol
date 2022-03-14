//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IModule {
    function membership() external returns (address);

    function timelock() external returns (address);
}
