// SPDX-License-Identifier: MIT

pragma solidity ^0.8.12;

import './utils/helpers.t.sol';
import '../../contracts/core/Membership.sol';
import 'forge-std/console2.sol';

contract MembershipTest is Helpers {
    function setUp() public {
        setUpMerkle();
        contractsReady();
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

    function generateProof(uint256 i) public {
        allowlistAddresses = new address[](i + 1);
        leafNodes = new bytes32[](i + 1);
        merkleProofs = new bytes32[][](i + 1);
        allowlistAddresses[0] = deployer;

        for (uint256 j = 1; j < i; j++) {
            allowlistAddresses[j] = address(uint160(j));
        }

        for (uint256 k = 0; k < allowlistAddresses.length; k++) {
            leafNodes[k] = keccak256(abi.encodePacked(allowlistAddresses[k]));
        }

        merkleRoot = m.getRoot(leafNodes);

        bytes32[] memory data = leafNodes;
        for (uint256 k = 0; k < allowlistAddresses.length; k++) {
            bytes32[] memory proof = m.getProof(data, k);
            merkleProofs[k] = proof;
        }

        badProof = m.getProof(data, allowlistAddresses.length);
    }

    function testGenerateProofFixed() public {
        generateProof(4);
        for (uint256 i = 0; i < 4 + 1; i++) {
            bytes32 valueToProve = keccak256(abi.encodePacked(allowlistAddresses[i]));
            assertTrue(m.verifyProof(merkleRoot, merkleProofs[i], valueToProve));
        }
    }

    // Should able to mint NFT for account in allowlist
    function testMembershipMintAllowlist() public {
        generateProof(4);
        membership.updateAllowlist(merkleRoot);
        vm.prank(address(1));
        membership.mint(merkleProofs[1]);
    }

    // Should not able to mint NFT for an account more than once
    function testMembershipMintAllowlistFailMoreThanOnce() public {
        generateProof(4);
        membership.updateAllowlist(merkleRoot);
        vm.prank(address(1));
        membership.mint(merkleProofs[1]);
        vm.prank(address(1));
        vm.expectRevert(Errors.MembershipAlreadyClaimed.selector);
        membership.mint(merkleProofs[1]);
    }

    // Should not able to mint NFT for account in allowlist with badProof
    function testMembershipMintFailBadProof() public {
        generateProof(4);
        membership.updateAllowlist(merkleRoot);
        vm.prank(address(1));
        vm.expectRevert(Errors.InvalidProof.selector);
        membership.mint(badProof);
    }

    // Should not able to mint NFT for account not in allowlist
    function testMembershipMintFailNotInAllowlist() public {
        generateProof(4);
        membership.updateAllowlist(merkleRoot);
        vm.prank(address(10));
        vm.expectRevert(Errors.InvalidProof.selector);
        membership.mint(merkleProofs[1]);
    }

    // Should return a server-side token URI by default
    function testMembershipTokenURI() public {
        generateProof(4);
        membership.updateAllowlist(merkleRoot);
        vm.prank(address(1));
        membership.mint(merkleProofs[1]);
        assertEq(membership.tokenURI(0), 'https://codefordao.org/member/0');
    }

    // Should return a decentralized token URI after updated
    function testMembershipTokenURIUpdate() public {
        generateProof(4);
        membership.updateAllowlist(merkleRoot);
        vm.prank(address(1));
        membership.mint(merkleProofs[1]);
        vm.prank(address(1));
        membership.updateTokenURI(0, "{testKey:'testKey'}");
        assertEq(
            membership.tokenURI(0),
            'data:application/json;base64,e3Rlc3RLZXk6J3Rlc3RLZXknfQ=='
        );
    }

    // Should not able to transfer tokens after paused
    function testMembershipTokenTranferFailAfterPause() public {
        generateProof(4);
        membership.updateAllowlist(merkleRoot);
        vm.prank(address(1));
        membership.mint(merkleProofs[1]);
        vm.prank(address(1));
        vm.expectRevert(Errors.TokenTransferWhilePaused.selector);
        membership.transferFrom(address(1), address(2), 0);
    }

    // Should able to mint tokens even after paused
    function testMembershipTokenTranferMintAfterPause() public {
        generateProof(4);
        membership.updateAllowlist(merkleRoot);
        vm.prank(address(1));
        membership.mint(merkleProofs[1]);
        vm.prank(address(2));
        membership.mint(merkleProofs[2]);
        assertEq(membership.balanceOf(address(2)), 1);
        assertEq(membership.ownerOf(1), address(2));
    }
}
