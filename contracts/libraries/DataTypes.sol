//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library DataTypes {
    struct MembershipToken {
        string name;
        string symbol;
        string baseTokenURI;
    }

    struct ShareToken {
        string name;
        string symbol;
        uint256 initialSupply;
    }

    struct DAOSettings {
        bool enableMembershipTransfer;
        bool enableInvestment;
        uint256 votingDelay;
        uint256 votingPeriod;
        uint256 timelockDelay;
        uint256 shareGovernorProposalThreshold;
        uint256 quorumNumerator;
        uint256 shareGovernorQuorumNumerator;
        uint256 investThresholdInETH;
        address[] investInERC20;
        uint256[] investThresholdInERC20;
    }
}
