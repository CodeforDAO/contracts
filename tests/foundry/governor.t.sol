// SPDX-License-Identifier: MIT

pragma solidity ^0.8.12;

import 'forge-std/Test.sol';
import '../../contracts/core/Governor.sol';
import '../../contracts/core/Membership.sol';
import '../../contracts/core/Share.sol';
import '../../contracts/core/Treasury.sol';
import {DataTypes} from '../../contracts/libraries/DataTypes.sol';

contract GovernorTest is Test {
    address deployer;
    bool enableMembershipTransfer = false;
    uint256 initialSupply;
    Share share;
    Treasury treasury;
    Membership membership;
    TreasuryGovernor membershipGovernor;
    TreasuryGovernor shareGovernor;

    function setUp() public {
        deployer = msg.sender;

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
        if (initialSupply > 0) {
            share.mint(address(treasury), 1_000_000);
            treasury.updateShareSplit(DataTypes.ShareSplit(20, 10, 30, 40));
        }
        membership.grantRole(keccak256('DEFAULT_ADMIN_ROLE'), address(treasury));

        share.grantRole(keccak256('DEFAULT_ADMIN_ROLE'), address(treasury));
        share.grantRole(keccak256('MINTER_ROLE'), address(treasury));
        share.grantRole(keccak256('PAUSER_ROLE'), address(treasury));
        share.revokeRole(keccak256('DEFAULT_ADMIN_ROLE'), deployer);
        share.revokeRole(keccak256('MINTER_ROLE'), deployer);
        share.revokeRole(keccak256('PAUSER_ROLE'), deployer);

        // All membership NFT is set to be non-transferable by default
        if (!enableMembershipTransfer) {
            membership.pause();
        }
        membership.revokeRole(keccak256('PAUSER_ROLE'), deployer);

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
        treasury.grantRole(keccak256('PROPOSER_ROLE'), address(membershipGovernor));
        treasury.grantRole(keccak256('PROPOSER_ROLE'), address(shareGovernor));
        membership.setupGovernor(
            address(share),
            address(treasury),
            address(membershipGovernor),
            address(shareGovernor)
        );
        membership.revokeRole(keccak256('DEFAULT_ADMIN_ROLE'), deployer);
    }

    function testShare() public {
        assertEq(share.name(), 'CodeforDAOShare');
        assertEq(share.symbol(), 'CFD');
    }
}
