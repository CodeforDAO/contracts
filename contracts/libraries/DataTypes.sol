//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library DataTypes {
    // Basic token settings
    struct BaseToken {
        string name;
        string symbol;
    }

    // Governance and voting-related settings
    struct GovernorSettings {
        uint256 votingDelay;
        uint256 votingPeriod;
        uint256 quorumNumerator;
        uint256 proposalThreshold;
    }

    // Whether to allow DAO's vault to support funding with eth or erc20 token
    struct InvestmentSettings {
        bool enableInvestment;
        uint256 investThresholdInETH;
        uint256 investRatioInETH;
        address[] investInERC20;
        uint256[] investThresholdInERC20;
        uint256[] investRatioInERC20;
    }

    // DAO's shareholding setting
    // @notice: [0:100] is the range of the percentage of the total supply
    struct ShareSplit {
        uint8 members;
        uint8 investors;
        uint8 market;
        uint8 reserved;
    }

    struct ShareSettings {
        GovernorSettings governor;
        uint256 initialSupply;
        ShareSplit initialSplit;
    }

    struct MembershipSettings {
        GovernorSettings governor;
        bool enableMembershipTransfer;
        string baseTokenURI;
    }

    // DAO Global Settings Entry
    struct DAOSettings {
        uint256 timelockDelay;
        ShareSettings share;
        MembershipSettings membership;
        InvestmentSettings investment;
    }

    // Module related datatypes
    enum ProposalStatus {
        Pending,
        Scheduled,
        Executed
    }

    // Multi-signature governance proposal used by the core module
    struct MicroProposal {
        ProposalStatus status;
        uint256 confirmations;
        address[] targets;
        uint256[] values;
        bytes[] calldatas;
        string description;
    }

    // The pull payment structure supported by the module
    struct ModulePayment {
        bool approved;
        uint256 eth;
        mapping(address => uint256) erc20;
        uint256 expiredAt;
    }
}
