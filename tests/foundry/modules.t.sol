// SPDX-License-Identifier: MIT

pragma solidity ^0.8.12;

import './utils/helpers.t.sol';
import '../../contracts/core/Module.sol';
import '../../contracts/libraries/Errors.sol';
import 'forge-std/console2.sol';

contract GovernorTest is Helpers {
    address[] internal targets = new address[](1);
    uint256[] internal values = new uint256[](1);
    bytes[] internal calldatas = new bytes[](1);
    string public description = '<proposal description>';
    bytes32 public referId = keccak256(abi.encodePacked(uint256(0)));
    bytes32 public proposalId;

    event ModuleProposalCreated(
        address indexed module,
        bytes32 indexed id,
        address indexed sender,
        uint256 timestamp
    );

    event ModuleProposalConfirmed(
        address indexed module,
        bytes32 indexed id,
        address indexed sender,
        uint256 timestamp
    );

    function setUp() public {
        setUpProof();
        contractsReady();
        membershipMintAndDelegate();

        targets[0] = address(callReceiverMock);
        values[0] = uint256(0);
        calldatas[0] = abi.encodeWithSignature('mockFunction()');
    }

    // modules.js #listOperators
    function testModuleFunctions() public {
        // Should created with target operators
        uint256[] memory operators = new uint256[](2);
        operators[0] = 0;
        operators[1] = 1;

        assertEq(payroll.listOperators(), operators);
        assertEq(options.listOperators(), operators);
        assertEq(okr.listOperators(), operators);
    }

    function testModulePropose() public {
        // Should be able to propose by an operator
        vm.prank(deployer);
        proposalId = keccak256(
            abi.encode(targets, values, calldatas, 0, keccak256(bytes(description)))
        );
        vm.expectEmit(true, true, true, true);
        emit ModuleProposalCreated(address(payroll), proposalId, deployer, block.timestamp);
        payroll.propose(targets, values, calldatas, description, referId);
    }

    function testModuleProposeFailUnauth() public {
        // Should not be able to propose by unauth account
        vm.prank(address(2));
        vm.expectRevert(Errors.NotOperator.selector);
        payroll.propose(targets, values, calldatas, description, referId);
    }

    function testModuleProposeConfirm() public {
        testModulePropose();
        // Should be able to confirm by an operator
        vm.prank(deployer);
        vm.expectEmit(true, true, true, true);
        emit ModuleProposalConfirmed(address(payroll), proposalId, deployer, block.timestamp);
        payroll.confirm(proposalId);
    }
}
