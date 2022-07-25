// SPDX-License-Identifier: MIT

pragma solidity ^0.8.12;

import './utils/helpers.t.sol';
import '../../contracts/core/Governor.sol';
import 'forge-std/console2.sol';

contract GovernorTest is Helpers {
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
        address[] memory targets;
        targets = new address[](1);
        targets[0] = address(0);
        uint256[] memory values;
        values = new uint256[](1);
        values[0] = uint256(0);
        bytes[] memory calldatas;
        calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature('mockFunction()');

        assertEq(membership.balanceOf(deployer), 1);

        // vm.roll(100);
        // assertEq(membershipGovernor.getVotes(deployer, 0), 1);

        // vm.prank(deployer);
        // membershipGovernor.propose(targets, values, calldatas, '<proposal description>');
    }
}
