//SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import 'ds-test/test.sol';
import '../../contracts/core/Membership.sol';
import '../../contracts/core/Share.sol';

abstract contract DAOTestHelper {
    Membership public membership;
    Share public share;
}

contract MembershipTest is DSTest {}
