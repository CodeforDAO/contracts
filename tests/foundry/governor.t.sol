// SPDX-License-Identifier: MIT

pragma solidity ^0.8.12;

import 'forge-std/Test.sol';
import '../../contracts/core/Governor.sol';
import '../../contracts/core/Membership.sol';
import '../../contracts/core/Share.sol';
import '../../contracts/core/Treasury.sol';
import {DataTypes} from '../../contracts/libraries/DataTypes.sol';

contract GovernorTest is Test {
    Share share;
    Treasury treasury;
    Membership membership;
    TreasuryGovernor membershipGovernor;
    TreasuryGovernor shareGovernor;

    function setUp() public {
        membership = new Membership(
            DataTypes.BaseToken({name: 'CodeforDAO', symbol: 'CODE'}),
            'https://codefordao.org/member/',
            'https://codefordao.org/membership/'
        );
        share = new Share('CodeforDAOShare', 'CFD');
        treasury = new Treasury(
            1,
            address(membership),
            address(share),
            DataTypes.InvestmentSettings(
                true,
                1,
                2,
                new address[](0),
                new uint256[](0),
                new uint256[](0)
            )
        );
        membershipGovernor = new TreasuryGovernor(
            string.concat(membership.name(), '-MembershipGovernor'),
            address(membership),
            treasury,
            DataTypes.GovernorSettings(0, 2, 3, 1)
        );
        shareGovernor = new TreasuryGovernor(
            string.concat(membership.name(), '-ShareGovernor'),
            address(share),
            treasury,
            DataTypes.GovernorSettings(1000, 10000, 4, 100)
        );
    }

    function testShare() public {
        assertEq(share.name(), 'CodeforDAOShare');
        assertEq(share.symbol(), 'CFD');
    }
}
