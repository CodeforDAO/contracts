//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/utils/Context.sol";

contract Share is 
  Context, 
  AccessControlEnumerable, 
  ERC20Burnable, 
  ERC20Pausable,
  ERC20Votes 
{
  bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
  bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

  constructor(
    string memory name,
    string memory symbol
  ) ERC20(name, symbol)
    ERC20Permit(name) {
    _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());

    _setupRole(MINTER_ROLE, _msgSender());
    _setupRole(PAUSER_ROLE, _msgSender());
  }

  function mint(address to, uint256 amount) public virtual {
    require(hasRole(MINTER_ROLE, _msgSender()), "Share: must have minter role to mint");
    _mint(to, amount);
  }

  function pause() public virtual {
    require(hasRole(PAUSER_ROLE, _msgSender()), "Share: must have pauser role to pause");
    _pause();
  }

  function unpause() public virtual {
    require(hasRole(PAUSER_ROLE, _msgSender()), "Share: must have pauser role to unpause");
    _unpause();
  }

  function _mint(address account, uint256 amount) internal virtual override(ERC20, ERC20Votes) {
    super._mint(account, amount);
  }

  function _burn(address account, uint256 amount) internal virtual override(ERC20, ERC20Votes) {
    super._burn(account, amount);
  }

  function _beforeTokenTransfer(
    address from,
    address to,
    uint256 amount
  ) internal virtual override(ERC20, ERC20Pausable) {
    super._beforeTokenTransfer(from, to, amount);
  }

  function _afterTokenTransfer(
    address from,
    address to,
    uint256 amount
  ) internal virtual override(ERC20, ERC20Votes) {
    super._afterTokenTransfer(from, to, amount);
  }
}