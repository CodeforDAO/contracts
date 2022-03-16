//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {DataTypes} from '../libraries/DataTypes.sol';

interface ITreasury {
    function updateShareSplit(DataTypes.ShareSplit memory _shareSplit) external;

    function vestingShare(uint256[] calldata tokenId, uint8[] calldata shareRatio) external;

    function updateInvestmentSettings(DataTypes.InvestmentSettings memory settings) external;

    function invest() external payable;

    function investInERC20(address token) external;

    function pullModulePayment(
        uint256 eth,
        address[] calldata tokens,
        uint256[] calldata amounts
    ) external;

    function approveModulePayment(
        address moduleAddress,
        uint256 eth,
        address[] calldata tokens,
        uint256[] calldata amounts
    ) external;
}
