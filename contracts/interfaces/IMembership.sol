//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC721/IERC721.sol';

interface IMembership is IERC721 {
    function mint(bytes32[] calldata proof) external;

    function investMint(address to) external returns (uint256);

    function isInvestor(uint256 tokenId) external view returns (bool);

    function updateWhitelist(bytes32 merkleTreeRoot_) external;

    function tokenURI(uint256 tokenId) external view returns (string memory);

    function updateTokenURI(uint256 tokenId, string calldata dataURI) external;

    function pause() external;

    function unpause() external;

    function setupGovernor() external;

    event InvestorAdded(address indexed investor, uint256 indexed tokenId, uint256 timestamp);
}
