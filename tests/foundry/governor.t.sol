// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import 'forge-std/Test.sol';
import '../../contracts/core/Governor.sol';
import '../../contracts/core/Membership.sol';
import '../../contracts/core/Share.sol';
import {DataTypes} from '../../contracts/libraries/DataTypes.sol';

contract GovernorTest is Test {
    Share share;
    Membership membership;
    TreasuryGovernor governor;

    function setUp() public {
        share = new Share('CodeforDAOShare', 'CFD');
        membership = new Membership(
            DataTypes.BaseToken({name: 'CodeforDAO', symbol: 'CODE'}),
            'https://codefordao.org/member/',
            'https://codefordao.org/membership/'
        );
        governor = new TreasuryGovernor(
            'CodeforDAO',
            address(0),
            Treasury(payable(address(0))),
            DataTypes.GovernorSettings(0, 2, 3, 1)
        );
    }

    function testShare() public {
        assertEq(share.name(), 'CodeforDAOShare');
        assertEq(share.symbol(), 'CFD');
    }
}
