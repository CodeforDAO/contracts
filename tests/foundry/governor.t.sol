// SPDX-License-Identifier: MIT

pragma solidity ^0.8.12;

import './utils/helpers.t.sol';
import '../../contracts/core/Governor.sol';
import 'forge-std/console2.sol';

contract GovernorTest is Helpers {
    event ProposalCreated(
        uint256 proposalId,
        address proposer,
        address[] targets,
        uint256[] values,
        string[] signatures,
        bytes[] calldatas,
        uint256 startBlock,
        uint256 endBlock,
        string description
    );

    function setUp() public {
        setUpProof();
        contractsReady();
        membershipMintAndDelegate();
    }

    function testMembershipGovernor() public {
        console2.log(address(this));
    }

    // governor.js #propose
    function testMembershipGovernorPropose() public {
        address[] memory targets = new address[](1);
        targets[0] = address(0);
        uint256[] memory values = new uint256[](1);
        values[0] = uint256(0);
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature('mockFunction()');
        string[] memory signatures = new string[](1);
        signatures[0] = '';

        vm.roll(block.number + 1);
        assertEq(membershipGovernor.getVotes(deployer, block.number - 1), 1);

        vm.prank(deployer);
        vm.expectEmit(true, true, true, true);
        emit ProposalCreated(
            73267620643934072697764220838761558643702153097420137858599584192610788443557,
            deployer,
            targets,
            values,
            signatures,
            calldatas,
            2,
            4,
            '<proposal description>'
        );
        membershipGovernor.propose(targets, values, calldatas, '<proposal description>');
    }
}
