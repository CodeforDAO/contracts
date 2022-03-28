//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'hardhat/console.sol';
import '@openzeppelin/contracts/utils/Strings.sol';
import '@openzeppelin/contracts/utils/Address.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {Module} from '../core/Module.sol';
import {IMembership} from '../interfaces/IMembership.sol';

/**
 * @title Payroll Module
 * @notice The Payroll module enables the payment of monthly, weekly, annual bonuses and dividends by managing the payroll list of DAO members. It provides a quick way to help managers create module proposals.
 */
contract Payroll is Module {
    using Strings for uint256;
    using Address for address payable;

    enum PayrollType {
        Salary,
        Bonus,
        Commission,
        Dividend,
        Other
    }

    enum PayrollPeriod {
        Monthly,
        Quarterly,
        Yearly,
        OneTime
    }

    struct PayrollInTokens {
        address[] tokens;
        uint256[] amounts;
    }

    struct PayrollDetail {
        uint256 amount;
        PayrollType paytype;
        PayrollPeriod period;
        PayrollInTokens tokens;
    }

    event PayrollAdded(uint256 indexed memberId, PayrollDetail payroll);
    event PayrollScheduled(uint256 indexed memberId, bytes32 proposalId);
    event PayrollExecuted(address indexed account, uint256 indexed memberId, uint256 amount);

    // MemberId => (PayrollPeriod => PayrollDetail[])
    mapping(uint256 => mapping(PayrollPeriod => PayrollDetail[])) private _payrolls;
    string[] private _payrollTypes = ['Salary', 'Bonus', 'Commission', 'Dividend', 'Other'];
    string[] private _payrollPeriods = ['Monthly', 'Quarterly', 'Yearly', 'OneTime'];

    constructor(
        address membership,
        uint256[] memory operators,
        uint256 delay
    ) Module('Payroll', 'Payroll Module V1', membership, operators, delay) {}

    /**
     * @dev Get Payroll
     * Get compensation plans of a member
     */
    function getPayroll(uint256 memberId, PayrollPeriod period)
        public
        view
        returns (PayrollDetail[] memory)
    {
        return _payrolls[memberId][period];
    }

    /**
     * @dev Add Payroll
     * Add a compensation plan for a member
     */
    function addPayroll(uint256 memberId, PayrollDetail calldata payroll) public onlyOperator {
        _payrolls[memberId][payroll.period].push(payroll);
        emit PayrollAdded(memberId, payroll);
    }

    /**
     * @dev Schedule Payroll
     * Adding a member's compensation proposal to the compensation cycle
     */
    function schedulePayroll(uint256 memberId, PayrollPeriod period)
        public
        onlyOperator
        returns (bytes32 _proposalId)
    {
        PayrollDetail[] memory payrolls = getPayroll(memberId, period);
        address[] memory targets = new address[](payrolls.length);
        uint256[] memory values = new uint256[](payrolls.length);
        bytes[] memory calldatas = new bytes[](payrolls.length);
        string memory description = string(
            abi.encodePacked(
                _payrollPeriods[uint256(period)],
                ' Payroll for #',
                memberId.toString(),
                ' (',
                _payrollTypes[uint256(payrolls[0].paytype)],
                ') ',
                '@',
                block.timestamp.toString()
            )
        );

        address memberWallet = getAddressByMemberId(memberId);

        for (uint256 i = 0; i < payrolls.length; i++) {
            PayrollDetail memory payroll = payrolls[i];
            targets[i] = address(this);
            values[i] = payroll.amount;

            // TODO: use byte4(func selector) to reduce the size of calldata
            calldatas[i] = abi.encodeWithSignature(
                'execTransfer(address,uint256,address[],uint256[])',
                memberId,
                memberWallet,
                payroll.tokens.tokens,
                payroll.tokens.amounts
            );
        }

        _proposalId = propose(targets, values, calldatas, description);

        emit PayrollScheduled(memberId, _proposalId);
    }

    /**
     * @dev Exec Transfer
     * Hook method for payroll proposals
     */
    function execTransfer(
        address payable account,
        uint256 memberId,
        address[] calldata tokens,
        uint256[] calldata amounts
    ) external payable onlyTimelock {
        if (msg.value > 0) {
            account.sendValue(msg.value);
        }

        // TODO: only pull required tokens
        pullPayments(0, tokens, amounts);

        for (uint256 i = 0; i < tokens.length; i++) {
            if (IERC20(tokens[i]).balanceOf(address(timelock)) >= amounts[i]) {
                IERC20(tokens[i]).transferFrom(address(timelock), address(account), amounts[i]);
            }
        }

        emit PayrollExecuted(account, memberId, msg.value);
    }
}
