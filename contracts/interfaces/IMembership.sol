//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC721/IERC721.sol';
import '@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol';

interface IMembership is IERC721, IERC721Enumerable {
    function treasury() external view returns (address);

    function governor() external view returns (address);

    function shareToken() external view returns (address);

    function shareGovernor() external view returns (address);

    function mint(bytes32[] calldata proof) external;

    function investMint(address to) external returns (uint256);

    function isInvestor(uint256 tokenId) external view returns (bool);

    function updateAllowlist(bytes32 merkleTreeRoot_) external;

    function tokenURI(uint256 tokenId) external view returns (string memory);

    function updateTokenURI(uint256 tokenId, string calldata dataURI) external;

    function pause() external;

    function unpause() external;

    function setupGovernor() external;

    event InvestorAdded(address indexed investor, uint256 indexed tokenId, uint256 timestamp);
}
