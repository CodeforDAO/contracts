// SPDX-License-Identifier: MIT

pragma solidity ^0.8.12;

import './utils/helpers.t.sol';
import '../../contracts/core/Module.sol';
import 'forge-std/console2.sol';

contract GovernorTest is Helpers {
    function setUp() public {
        setUpProof();
        contractsReady();
        membershipMintAndDelegate();
    }
}
