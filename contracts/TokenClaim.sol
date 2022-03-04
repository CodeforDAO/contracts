//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract TokenClaim is ERC20, AccessControl {
  uint256 public totalClaims;
  bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
  address public constant TEST_WALLET = 0xb0daCC029B2722055B71c6839Fb56d1EEE4Db2F2;
  mapping(address => uint256) public claims;

  constructor() 
    ERC20("CodeforDAO", "CODE") {
    _mint(address(this), _wrapNumber(1000));
    _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    _setupRole(MINTER_ROLE, TEST_WALLET);
  }

  function _wrapNumber(uint256 _num) private pure returns (uint256) {
    return _num * 10**18;
  }
  
  function bulkAddToClaims(address[] memory _addresses, uint256[] memory _claims) public onlyRole(MINTER_ROLE) {
    for (uint i = 0; i < _addresses.length; i++) {
      addToClaims(_addresses[i], _claims[i]);
    }
  }

  function addToClaims(address _claimant, uint256 _amount) public onlyRole(MINTER_ROLE) {
    require(_amount > 0);
    require(_claimant != address(0));
    require(_wrapNumber(totalClaims) <= ERC20(this).balanceOf(address(this)));

    claims[_claimant] += _amount;
    totalClaims += _amount;
  }

  function claimTokens(address _claimant) public {
    require(_claimant != address(0));
    require(claims[_claimant] > 0);
    require(_wrapNumber(claims[_claimant]) <= ERC20(this).balanceOf(address(this)));

    ERC20(this).transfer(_claimant, _wrapNumber(claims[_claimant]));

    totalClaims -= claims[_claimant];
    claims[_claimant] = 0;
  }

  function getClaimsByAddress(address _claimant) public view returns (uint256) {
    return claims[_claimant];
  }
}
