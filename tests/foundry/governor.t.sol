// SPDX-License-Identifier: MIT

pragma solidity ^0.8.12;

import './utils/helpers.t.sol';

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

    function testMembershipDeploymentCheck() public {
        // Should bind a membership governor (1/1) contract
        assertEq(membership.governor(), address(membershipGovernor));
        // Should bind a share token (ERC20) contract
        assertEq(membership.shareToken(), address(share));
        assertEq(share.name(), 'CodeforDAOShare');
    }
}
