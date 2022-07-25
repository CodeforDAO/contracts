// SPDX-License-Identifier: MIT

pragma solidity ^0.8.12;

import './utils/helpers.t.sol';
import '../../contracts/core/Membership.sol';
import 'forge-std/console2.sol';

contract MembershipTest is Helpers {
    function setUp() public {
        setUpProof();
        contractsReady();
    }

    function testShare() public {
        assertEq(share.name(), 'CodeforDAOShare');
        assertEq(share.symbol(), 'CFD');
    }

    // membership.js #setupGovernor
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

    // membership.js #updateAllowlist
    function testMembershipUpdateAllowList() public {
        vm.prank(address(0));
        vm.expectRevert(Errors.NotInviter.selector);
        membership.updateAllowlist(merkleRoot);
    }

    // Should able to mint NFT for account in allowlist
    function testMembershipMintAllowlist() public {
        membership.updateAllowlist(merkleRoot);
        vm.prank(deployer);
        membership.mint(merkleProofs[0]);
    }

    // Should not able to mint NFT for an account more than once
    function testMembershipMintAllowlistFailMoreThanOnce() public {
        generateProof(4);
        membership.updateAllowlist(merkleRoot);
        vm.prank(deployer);
        membership.mint(merkleProofs[0]);
        vm.prank(deployer);
        vm.expectRevert(Errors.MembershipAlreadyClaimed.selector);
        membership.mint(merkleProofs[0]);
    }

    // Should not able to mint NFT for account in allowlist with badProof
    function testMembershipMintFailBadProof() public {
        membership.updateAllowlist(merkleRoot);
        vm.prank(deployer);
        vm.expectRevert(Errors.InvalidProof.selector);
        membership.mint(badProof);
    }

    // Should not able to mint NFT for account not in allowlist
    function testMembershipMintFailNotInAllowlist() public {
        membership.updateAllowlist(merkleRoot);
        vm.prank(address(100_000));
        vm.expectRevert(Errors.InvalidProof.selector);
        membership.mint(merkleProofs[1]);
    }

    // Should return a server-side token URI by default
    function testMembershipTokenURI() public {
        membership.updateAllowlist(merkleRoot);
        vm.prank(deployer);
        membership.mint(merkleProofs[0]);
        assertEq(membership.tokenURI(0), 'https://codefordao.org/member/0');
    }

    // Should return a decentralized token URI after updated
    function testMembershipTokenURIUpdate() public {
        membership.updateAllowlist(merkleRoot);
        vm.prank(deployer);
        membership.mint(merkleProofs[0]);
        vm.prank(deployer);
        membership.updateTokenURI(0, "{testKey:'testKey'}");
        assertEq(
            membership.tokenURI(0),
            'data:application/json;base64,e3Rlc3RLZXk6J3Rlc3RLZXknfQ=='
        );
    }

    // Should not able to transfer tokens after paused
    function testMembershipTokenTranferFailAfterPause() public {
        membership.updateAllowlist(merkleRoot);
        vm.prank(deployer);
        membership.mint(merkleProofs[0]);
        vm.prank(deployer);
        vm.expectRevert(Errors.TokenTransferWhilePaused.selector);
        membership.transferFrom(deployer, address(1), 0);
    }

    // Should able to mint tokens even after paused
    function testMembershipTokenTranferMintAfterPause() public {
        membership.updateAllowlist(merkleRoot);
        vm.prank(deployer);
        membership.mint(merkleProofs[0]);
        vm.prank(address(1));
        membership.mint(merkleProofs[1]);
        assertEq(membership.balanceOf(address(1)), 1);
        assertEq(membership.ownerOf(1), address(1));
    }
}
