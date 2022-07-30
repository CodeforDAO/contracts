// SPDX-License-Identifier: MIT

pragma solidity ^0.8.12;

import './utils/helpers.t.sol';
import '../../contracts/core/Module.sol';
import '../../contracts/mocks/CallReceiverMock.sol';
import '../../contracts/libraries/Errors.sol';
import '../../contracts/interfaces/IModulePayroll.sol';
import 'forge-std/console2.sol';

contract GovernorTest is Helpers {
    address[] internal targets = new address[](1);
    uint256[] internal values = new uint256[](1);
    bytes[] internal calldatas = new bytes[](1);
    string public description = '<proposal description>';
    bytes32 public referId = keccak256(abi.encodePacked(uint256(0)));
    bytes32 public proposalId;

    address[] addresses = new address[](0);
    uint256[] amounts = new uint256[](0);

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

    event ModuleProposalExecuted(
        address indexed module,
        bytes32 indexed id,
        address indexed sender,
        uint256 timestamp
    );

    event ModuleProposalScheduled(
        address indexed module,
        bytes32 indexed id,
        address indexed sender,
        uint256 timestamp
    );

    event CallExecuted(
        bytes32 indexed id,
        uint256 indexed index,
        address target,
        uint256 value,
        bytes data
    );

    event MockFunctionCalled();

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

    function testModuleProposeSchedule() public {
        testModuleProposeConfirm();

        vm.prank(address(1));
        vm.expectEmit(true, true, true, true);
        emit ModuleProposalConfirmed(address(payroll), proposalId, address(1), block.timestamp);
        payroll.confirm(proposalId);

        vm.prank(deployer);
        vm.expectEmit(true, true, true, true);
        emit ModuleProposalScheduled(address(payroll), proposalId, deployer, block.timestamp);
        payroll.schedule(proposalId);
    }

    function testModuleProposeExecute() public {
        testModuleProposeSchedule();

        vm.warp(block.timestamp + 200);

        vm.prank(deployer);
        vm.expectEmit(true, false, false, true);
        vm.expectEmit(true, true, true, true);
        vm.expectEmit(true, true, true, true);
        emit MockFunctionCalled();
        emit CallExecuted(proposalId, 0, address(callReceiverMock), 0, calldatas[0]);
        emit ModuleProposalExecuted(address(payroll), proposalId, deployer, block.timestamp);
        payroll.execute(proposalId);
    }

    function testPayrollAdd() public {
        payroll.addPayroll(
            0,
            IModulePayroll.PayrollDetail(
                0,
                IModulePayroll.PayrollType.Salary,
                IModulePayroll.PayrollPeriod.Monthly,
                IModulePayroll.PayrollInTokens(addresses, amounts)
            )
        );
    }
}
