//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IModulePayroll {
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
        address[] addresses;
        uint256[] amounts;
    }

    struct PayrollDetail {
        uint256 amount;
        PayrollType paytype;
        PayrollPeriod period;
        PayrollInTokens tokens;
    }

    struct PayrollKeys {
        uint256 memberId;
        PayrollPeriod period;
    }

    event PayrollAdded(uint256 indexed memberId, PayrollDetail payroll);
    event PayrollScheduled(uint256 indexed memberId, bytes32 proposalId);
    event PayrollExecuted(address indexed account, uint256 indexed memberId, uint256 amount);

    function getPayroll(uint256 memberId, PayrollPeriod period)
        external
        view
        returns (PayrollDetail[] memory);

    function addPayroll(uint256 memberId, PayrollDetail calldata payroll) external;

    function schedulePayroll(uint256 memberId, PayrollPeriod period)
        external
        returns (bytes32 _proposalId);
}
