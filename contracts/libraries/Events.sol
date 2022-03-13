//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library Events {
    event InvestorAdded(address indexed investor, uint256 indexed tokenId, uint256 timestamp);

    event InvestInETH(address indexed investor, uint256 amount, uint256 shareAmount);

    event InvestInERC20(
        address indexed investor,
        address indexed tokenAddress,
        uint256 amount,
        uint256 shareAmount
    );

    event ModuleAdded(address indexed module, uint256 timestamp, address indexed operator);

    event ModuleRemoved(address indexed module, uint256 timestamp, address indexed operator);
}
