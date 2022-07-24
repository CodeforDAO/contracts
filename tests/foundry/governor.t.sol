// SPDX-License-Identifier: MIT

pragma solidity ^0.8.12;

import './utils/helpers.t.sol';
import '../../contracts/core/Membership.sol';

contract GovernorTest is Helpers {
    function setUp() public {
        setUpProof(3);
        contractsReady();
    }

    function testSetUpProof() public {
        setUpProof(4);
    }

    function testShare() public {
        assertEq(share.name(), 'CodeforDAOShare');
        assertEq(share.symbol(), 'CFD');
    }

    // membership.js deployment check
    function testMembershipDeploymentCheck() public {
        // Should bind a membership governor (1/1) contract
        assertEq(membership.governor(), address(membershipGovernor));
        // Should bind a share token (ERC20) contract
        assertEq(membership.shareToken(), address(share));
        assertEq(share.name(), 'CodeforDAOShare');
        assertEq(share.symbol(), 'CFD');
        // Should bind a share governor (ERC20 IVotes) contract
        assertEq(membership.shareGovernor(), address(shareGovernor));
        // Should bind a treasury (timelock) contract
        assertEq(membershipGovernor.timelock(), address(treasury));
    }

    // membership.js setup governor tests
    function testMembershipSetupGovernor() public {
        // Should not be able to call by a invaid account
        vm.prank(address(0));
        vm.expectRevert(
            bytes(
                'AccessControl: account 0x0000000000000000000000000000000000000000 is missing role 0x0000000000000000000000000000000000000000000000000000000000000000'
            )
        );
        membership.setupGovernor(
            address(membership),
            address(membership),
            address(membership),
            address(membership)
        );
        // Should be able to setup the governor contract roles
        assertEq(treasury.hasRole(keccak256('PROPOSER_ROLE'), address(membershipGovernor)), true);
        assertEq(treasury.hasRole(keccak256('PROPOSER_ROLE'), address(shareGovernor)), true);
        assertEq(treasury.hasRole(keccak256('EXECUTOR_ROLE'), address(0)), true);
        // The init timelock admin role should be set to false
        assertEq(treasury.hasRole(keccak256('TIMELOCK_ADMIN_ROLE'), address(membership)), false);
        // Make sure the share token has right roles
        assertEq(share.hasRole(keccak256('DEFAULT_ADMIN_ROLE'), address(treasury)), true);
        assertEq(share.hasRole(keccak256('MINTER_ROLE'), address(treasury)), true);
        assertEq(share.hasRole(keccak256('PAUSER_ROLE'), address(treasury)), true);
        assertEq(share.hasRole(keccak256('DEFAULT_ADMIN_ROLE'), address(membership)), false);
        assertEq(share.hasRole(keccak256('MINTER_ROLE'), address(membership)), false);
        assertEq(share.hasRole(keccak256('PAUSER_ROLE'), address(membership)), false);
        // Make sure initialSupply is minted
        assertEq(share.balanceOf(address(treasury)), initialSupply);
        // Make sure token transfer is paused by default
        assertEq(share.paused(), enableMembershipTransfer);
        // Deployer's role should be revoked
        assertEq(membership.hasRole(keccak256('PAUSER_ROLE'), address(deployer)), false);
        assertEq(membership.hasRole(keccak256('DEFAULT_ADMIN_ROLE'), address(deployer)), false);
    }
}
