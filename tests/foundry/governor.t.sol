// SPDX-License-Identifier: MIT

pragma solidity ^0.8.12;

import './utils/helpers.t.sol';
import '../../contracts/core/Governor.sol';
import 'forge-std/console2.sol';

contract GovernorTest is Helpers {
    address[] internal targets = new address[](1);
    uint256[] internal values = new uint256[](1);
    bytes[] internal calldatas = new bytes[](1);
    string[] internal signatures = new string[](1);
    uint256 internal proposalId =
        73267620643934072697764220838761558643702153097420137858599584192610788443557;

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
    event VoteCast(
        address indexed voter,
        uint256 proposalId,
        uint8 support,
        uint256 weight,
        string reason
    );

    function setUp() public {
        setUpProof();
        contractsReady();
        membershipMintAndDelegate();

        targets[0] = address(0);
        values[0] = uint256(0);
        calldatas[0] = abi.encodeWithSignature('mockFunction()');
        signatures[0] = '';

        vm.roll(block.number + 1);
        assertEq(membershipGovernor.getVotes(deployer, block.number - 1), 1);
    }

    // governor.js #propose
    function testMembershipGovernorPropose() public {
        _voteOnProposal();

        // Should not able to make a valid propose if user do not hold a NFT membership'
        vm.prank(address(0));
        vm.expectRevert(bytes('Governor: proposer votes below proposal threshold'));
        membershipGovernor.propose(targets, values, calldatas, '<proposal description>');
    }

    // governor.js #vote
    function testMembershipGovernorVote() public {
        // Should able to cast votes on a valid proposal
        _voteOnProposal();

        vm.roll(block.number + 1);

        vm.prank(deployer);
        vm.expectEmit(true, true, true, true);
        emit VoteCast(deployer, proposalId, 1, 1, '');
        membershipGovernor.castVote(proposalId, 1);
        assertEq(membershipGovernor.hasVoted(proposalId, deployer), true);

        vm.prank(address(1));
        vm.expectEmit(true, true, true, true);
        emit VoteCast(address(1), proposalId, 1, 1, "I don't like this proposal");
        membershipGovernor.castVoteWithReason(proposalId, 1, "I don't like this proposal");

        vm.roll(block.number + 3);

        // console2.log(membershipGovernor.proposalSnapshot(proposalId));

        // vm.prank(deployer);
        // membershipGovernor.propose(targets, values, calldatas, '');
        // console2.log(
        //     membershipGovernor.proposalSnapshot(
        //         1121344006512388179016893516467415748208564667259029434537941439660230474763
        //     )
        // );

        // vm.roll(block.number + 4);

        // membershipGovernor.queue(
        //     targets,
        //     values,
        //     calldatas,
        //     bytes32(membershipGovernor.hashProposal(targets, values, calldatas, keccak256('')))
        // );
    }

    function _voteOnProposal() internal {
        vm.prank(deployer);
        vm.expectEmit(true, true, true, true);
        emit ProposalCreated(
            proposalId,
            deployer,
            targets,
            values,
            signatures,
            calldatas,
            2,
            4,
            '<proposal description>'
        );
        uint256 proposedId = membershipGovernor.propose(
            targets,
            values,
            calldatas,
            '<proposal description>'
        );
        assertEq(
            proposedId,
            uint256(
                keccak256(
                    abi.encode(targets, values, calldatas, keccak256('<proposal description>'))
                )
            )
        );
    }
}
