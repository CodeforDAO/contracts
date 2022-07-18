// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import 'forge-std/Test.sol';
import '../../contracts/core/Governor.sol';

contract GovernorTest is Test {
    TreasuryGovernor governor;

    function setUp() public {
        governor = new TreasuryGovernor(
            'CodeforDAO',
            address(0),
            Treasury(payable(address(0))),
            DataTypes.GovernorSettings(0, 0, 0, 0)
        );
    }
}
