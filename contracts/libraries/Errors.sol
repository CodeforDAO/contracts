//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library Errors {
    error NotInviter();
    error NotPauser();
    error NotMinter();
    error NotMember();
    error InvalidProof();
    error MembershipAlreadyClaimed();
    error TokenTransferWhilePaused();
    error VotesBelowProposalThreshold();
    error InvestmentDisabled();
    error InvestmentThresholdNotMet(uint256 thresholdNeeded);
    error InvestmentInERC20Disabled(address token);
    error InvestmentInERC20ThresholdNotMet(address token, uint256 thresholdNeeded);
    error NoShareInTreasury();
    error NoMembersShareToVest();
    error ModuleAlreadyRegistered();
    error ModuleNotRegistered();
    error NotOperator();
    error NotTimelock();
    error InvalidProposalStatus();
    error NotEnoughConfirmations();
    error AlreadyConfirmed();
    error ModuleNotApproved();
    error NotEnoughETH();
    error InvalidTokenAmounts();
    error NotEnoughTokens();

    string internal constant ERC721METADATA_NONEXIST_TOKEN =
        'ERC721Metadata: URI query for nonexistent token';

    string internal constant ERC721METADATA_UPDATE_NONEXIST_TOKEN =
        'ERC721Metadata: URI update for nonexistent token';

    string internal constant ERC721METADATA_UPDATE_UNAUTH =
        'ERC721Metadata: URI update for token not owned by sender';
}
