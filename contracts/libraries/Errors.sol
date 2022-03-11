//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library Errors {
    error MembershipAlreadyClaimed();
    error InvalidProof();
    error NotInviter();
    error NotPauser();
    error NotMinter();
    error TokenTransferWhilePaused();
    error VotesBelowProposalThreshold();

    string internal constant ERC721METADATA_NONEXIST_TOKEN =
        'ERC721Metadata: URI query for nonexistent token';

    string internal constant ERC721METADATA_UPDATE_NONEXIST_TOKEN =
        'ERC721Metadata: URI update for nonexistent token';

    string internal constant ERC721METADATA_UPDATE_UNAUTH =
        'ERC721Metadata: URI update for token not owned by sender';
}
