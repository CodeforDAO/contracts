//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol';
import '@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol';
import '@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol';
import '@openzeppelin/contracts/access/AccessControlEnumerable.sol';
import '@openzeppelin/contracts/utils/Context.sol';

import {Errors} from '../libraries/Errors.sol';

/**
 * @title Share
 * @notice The share contract determines the issuance and suspension of share tokens,
 * as well as the administrator role.
 * Basically it is a pre-defined contract for erc20 token but support ERC20Votes.
 */
contract Share is Context, AccessControlEnumerable, ERC20Burnable, ERC20Pausable, ERC20Votes {
    /// @dev keccak256('MINTER_ROLE');
    bytes32 public constant MINTER_ROLE =
        0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6;
    /// @dev keccak256('PAUSER_ROLE')
    bytes32 public constant PAUSER_ROLE =
        0x65d7a28e3265b37a6474929f336521b332c1681b933f6cb9f3376673440d862a;

    constructor(string memory name, string memory symbol) ERC20(name, symbol) ERC20Permit(name) {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());

        _setupRole(MINTER_ROLE, _msgSender());
        _setupRole(PAUSER_ROLE, _msgSender());
    }

    function mint(address to, uint256 amount) public virtual {
        if (!hasRole(MINTER_ROLE, _msgSender())) revert Errors.NotMinter();

        _mint(to, amount);
    }

    function pause() public virtual {
        if (!hasRole(PAUSER_ROLE, _msgSender())) revert Errors.NotPauser();

        _pause();
    }

    function unpause() public virtual {
        if (!hasRole(PAUSER_ROLE, _msgSender())) revert Errors.NotPauser();

        _unpause();
    }

    // @dev The functions below are overrides required by Solidity.
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
