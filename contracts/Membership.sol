//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Pausable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/draft-ERC721Votes.sol";
// import "@openzeppelin/contracts/governance/Governor.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/utils/Multicall.sol";

contract Membership is 
  AccessControlEnumerable,
  ERC721Enumerable, 
  ERC721Burnable, 
  ERC721Pausable,
  ERC721Votes,
  Multicall
{
  using Counters for Counters.Counter;

  bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
  bytes32 public constant INVITER_ROLE = keccak256("INVITER_ROLE");
  bytes32 public merkleTreeRoot;
  string public VERSION = "1";

  Counters.Counter private _tokenIdTracker;

  string private _baseTokenURI;

  constructor(
    string memory name,
    string memory symbol,
    string memory baseTokenURI
  ) ERC721(name, symbol) EIP712(name, VERSION) {
    _baseTokenURI = baseTokenURI;

    _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    _grantRole(PAUSER_ROLE, msg.sender);
  }

  function _baseURI() internal view override returns (string memory) {
    return _baseTokenURI;
  }

  function mint(bytes32[] calldata proof) public {
    require(balanceOf(msg.sender) < 1, "CodeforDAO Membership: address already claimed");
    require(MerkleProof.verify(proof, merkleTreeRoot, keccak256(abi.encodePacked(msg.sender))), "CodeforDAO Membership: Invalid proof");

    _mint(msg.sender, _tokenIdTracker.current());
    _tokenIdTracker.increment();
  }

  function updateRoot(bytes32 root) public {
    require(hasRole(INVITER_ROLE, msg.sender), "CodeforDAO Membership: must have inviter role to update root"); 

    merkleTreeRoot = root;
  }

  function pause() public {
    require(hasRole(PAUSER_ROLE, msg.sender), "CodeforDAO Membership: must have pauser role to pause");
    _pause();
  }

  function unpause() public {
    require(hasRole(PAUSER_ROLE, msg.sender), "CodeforDAO Membership: must have pauser role to unpause");
    _unpause();
  }

  function _beforeTokenTransfer(
    address from,
    address to,
    uint256 tokenId
  ) internal virtual override(ERC721, ERC721Enumerable, ERC721Pausable) {
    super._beforeTokenTransfer(from, to, tokenId);
  }

  function _afterTokenTransfer(
    address from,
    address to,
    uint256 tokenId
  ) internal virtual override(ERC721, ERC721Votes) {
    super._afterTokenTransfer(from, to, tokenId);
  }

  function supportsInterface(bytes4 interfaceId)
    public
    view
    virtual
    override(AccessControlEnumerable, ERC721, ERC721Enumerable)
    returns (bool)
  {
    return super.supportsInterface(interfaceId);
  }

  // function votingDelay() public pure override returns (uint256) {
  //   return 6575; // 1 day
  // }

  // function votingPeriod() public pure override returns (uint256) {
  //   return 46027; // 1 week
  // }

  // function proposalThreshold() public pure override returns (uint256) {
  //   return 0;
  // }
}