//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library DataTypes {
    struct BaseToken {
        string name;
        string symbol;
    }

    struct GovernorSettings {
        uint256 votingDelay;
        uint256 votingPeriod;
        uint256 quorumNumerator;
        uint256 proposalThreshold;
    }

    struct ShareSettings {
        GovernorSettings governor;
        uint256 initialSupply;
        bool enableInvestment;
        uint256 investThresholdInETH;
        address[] investInERC20;
        uint256[] investThresholdInERC20;
    }

    struct MembershipSettings {
        GovernorSettings governor;
        bool enableMembershipTransfer;
        string baseTokenURI;
    }

    struct DAOSettings {
        uint256 timelockDelay;
        ShareSettings share;
        MembershipSettings membership;
    }
}
