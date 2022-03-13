//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IMembership {
    function mint(bytes32[] calldata proof) external;

    function investMint(address to) external returns (uint256);

    function isInvestor(uint256 tokenId) external view returns (bool);

    function updateWhitelist(bytes32 merkleTreeRoot_) external;

    function tokenURI(uint256 tokenId) external view returns (string memory);

    function updateTokenURI(uint256 tokenId, string calldata dataURI) external;

    function pause() external;

    function unpause() external;

    function setupGovernor() external;
}
