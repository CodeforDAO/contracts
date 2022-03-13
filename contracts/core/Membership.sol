//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'hardhat/console.sol';
import '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import '@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol';
import '@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol';
import '@openzeppelin/contracts/security/Pausable.sol';
import '@openzeppelin/contracts/token/ERC721/extensions/draft-ERC721Votes.sol';
import '@openzeppelin/contracts/access/AccessControlEnumerable.sol';
import '@openzeppelin/contracts/utils/Counters.sol';
import '@openzeppelin/contracts/utils/cryptography/MerkleProof.sol';
import '@openzeppelin/contracts/utils/Multicall.sol';
import '@openzeppelin/contracts/utils/Strings.sol';
import '@openzeppelin/contracts/utils/Base64.sol';
import '@openzeppelin/contracts/utils/Context.sol';

// Core contracts of CodeforDAO
import './Treasury.sol';
import './Governor.sol';
import './Share.sol';
import {DataTypes} from '../libraries/DataTypes.sol';
import {Constants} from '../libraries/Constants.sol';
import {Errors} from '../libraries/Errors.sol';
import {Events} from '../libraries/Events.sol';

contract Membership is
    Context,
    AccessControlEnumerable,
    Pausable,
    ERC721Enumerable,
    ERC721Burnable,
    ERC721Votes,
    Multicall
{
    using Counters for Counters.Counter;
    using Strings for uint256;

    // Governance related contracts
    Treasury public immutable treasury;
    TreasuryGovernor public immutable governor;
    Share public immutable shareToken;
    TreasuryGovernor public shareGovernor;

    // NFT Membership related states
    bytes32 public constant PAUSER_ROLE = keccak256('PAUSER_ROLE');
    bytes32 public constant INVITER_ROLE = keccak256('INVITER_ROLE');
    string private _baseTokenURI;
    bytes32 private _merkleTreeRoot;
    Counters.Counter private _tokenIdTracker;
    DataTypes.DAOSettings private _initialSettings;
    mapping(uint256 => string) private _decentralizedStorage;
    mapping(uint256 => bool) private _isInvestor;

    constructor(
        DataTypes.BaseToken memory membership,
        DataTypes.BaseToken memory share,
        DataTypes.DAOSettings memory settings
    ) ERC721(membership.name, membership.symbol) EIP712(membership.name, '1') {
        _initialSettings = settings;
        _baseTokenURI = settings.membership.baseTokenURI;

        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _grantRole(PAUSER_ROLE, _msgSender());
        _grantRole(INVITER_ROLE, _msgSender());

        // Create DAO's share token
        shareToken = new Share(
            bytes(share.name).length > 0
                ? share.name
                : string(
                    abi.encodePacked(membership.name, Constants.SHARE_TOKEN_NAME_DEFAULT_SUFFIX)
                ),
            bytes(share.symbol).length > 0
                ? share.symbol
                : string(
                    abi.encodePacked(membership.symbol, Constants.SHARE_TOKEN_SYMBOL_DEFAULT_SUFFIX)
                )
        );

        // Create DAO's Treasury contract
        treasury = new Treasury({
            timelockDelay: settings.timelockDelay,
            membershipTokenAddress: address(this),
            shareTokenAddress: address(shareToken),
            settings: settings.investment
        });

        // Create DAO's 1/1 Membership Governance contract
        governor = new TreasuryGovernor({
            name: string(abi.encodePacked(membership.name, Constants.MEMBERSHIP_GOVERNOR_SUFFIX)),
            token: this,
            treasury: treasury,
            settings: settings.membership.governor
        });

        // Create DAO's share Governance
        shareGovernor = new TreasuryGovernor({
            name: string(abi.encodePacked(membership.name, Constants.SHARE_GOVERNOR_SUFFIX)),
            token: shareToken,
            treasury: treasury,
            settings: settings.share.governor
        });
    }

    function setupGovernor() public onlyRole(DEFAULT_ADMIN_ROLE) {
        bytes32 PROPOSER_ROLE = keccak256('PROPOSER_ROLE');
        bytes32 MINTER_ROLE = keccak256('MINTER_ROLE');

        // Setup governor roles
        // Both membership and share governance have PROPOSER_ROLE by default
        treasury.grantRole(PROPOSER_ROLE, address(governor));
        treasury.grantRole(PROPOSER_ROLE, address(shareGovernor));

        // Mint initial tokens to the treasury
        if (_initialSettings.share.initialSupply > 0) {
            shareToken.mint(address(treasury), _initialSettings.share.initialSupply);
            treasury.updateShareSplit(_initialSettings.share.initialSplit);
        }

        // Revoke `TIMELOCK_ADMIN_ROLE` from this deployer
        treasury.revokeRole(keccak256('TIMELOCK_ADMIN_ROLE'), address(this));

        // Make sure the DAO's Treasury contract controls everything
        grantRole(DEFAULT_ADMIN_ROLE, address(treasury));
        revokeRole(DEFAULT_ADMIN_ROLE, _msgSender());
        shareToken.grantRole(DEFAULT_ADMIN_ROLE, address(treasury));
        shareToken.grantRole(MINTER_ROLE, address(treasury));
        shareToken.grantRole(PAUSER_ROLE, address(treasury));
        shareToken.revokeRole(MINTER_ROLE, address(this));
        shareToken.revokeRole(PAUSER_ROLE, address(this));
        shareToken.revokeRole(DEFAULT_ADMIN_ROLE, address(this));

        // All membership NFT is set to be non-transferable by default
        if (!_initialSettings.membership.enableMembershipTransfer) {
            pause();
        }

        revokeRole(PAUSER_ROLE, _msgSender());

        // reserved the INVITER_ROLE case we need it to modify the whitelist by a non-admin deployer address.
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), Errors.ERC721METADATA_NONEXIST_TOKEN);

        string memory baseURI = _baseURI();

        if (bytes(_decentralizedStorage[tokenId]).length > 0) {
            return
                string(
                    abi.encodePacked(
                        'data:application/json;base64,',
                        Base64.encode(bytes(_decentralizedStorage[tokenId]))
                    )
                );
        }

        return
            bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, tokenId.toString())) : '';
    }

    // Self-mint for white-listed members
    function mint(bytes32[] calldata proof) public {
        if (balanceOf(_msgSender()) > 0) revert Errors.MembershipAlreadyClaimed();

        if (!MerkleProof.verify(proof, _merkleTreeRoot, keccak256(abi.encodePacked(_msgSender()))))
            revert Errors.InvalidProof();

        // tokenId start with 0
        _mint(_msgSender(), _tokenIdTracker.current());
        _tokenIdTracker.increment();
    }

    // Treasury could mint for a investor by pass the whitelist check
    function investMint(address to) external onlyRole(DEFAULT_ADMIN_ROLE) returns (uint256) {
        if (balanceOf(to) > 0) {
            uint256 tokenId = tokenOfOwnerByIndex(to, 0);
            _isInvestor[tokenId] = true;
            emit Events.InvestorAdded(to, tokenId, block.timestamp);
            return tokenId;
        }

        uint256 _tokenId = _tokenIdTracker.current();
        _mint(to, _tokenId);
        _isInvestor[_tokenId] = true;
        emit Events.InvestorAdded(to, _tokenId, block.timestamp);
        _tokenIdTracker.increment();
        return _tokenId;
    }

    function isInvestor(uint256 tokenId) public view returns (bool) {
        return _isInvestor[tokenId];
    }

    // Switch for the use of decentralized storage
    function updateTokenURI(uint256 tokenId, string calldata dataURI) public {
        require(_exists(tokenId), Errors.ERC721METADATA_UPDATE_NONEXIST_TOKEN);
        require(ownerOf(tokenId) == _msgSender(), Errors.ERC721METADATA_UPDATE_UNAUTH);

        _decentralizedStorage[tokenId] = dataURI;
    }

    function updateWhitelist(bytes32 merkleTreeRoot_) public {
        if (!hasRole(INVITER_ROLE, _msgSender())) revert Errors.NotInviter();

        _merkleTreeRoot = merkleTreeRoot_;
    }

    function pause() public {
        if (!hasRole(PAUSER_ROLE, _msgSender())) revert Errors.NotPauser();

        _pause();
    }

    function unpause() public {
        if (!hasRole(PAUSER_ROLE, _msgSender())) revert Errors.NotPauser();

        _unpause();
    }

    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);

        // Pause status won't block mint operation
        if (from != address(0) && paused()) revert Errors.TokenTransferWhilePaused();
    }

    function _afterTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override(ERC721, ERC721Votes) {
        super._afterTokenTransfer(from, to, tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(AccessControlEnumerable, ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
