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
import '@openzeppelin/contracts/utils/Strings.sol';
import '@openzeppelin/contracts/utils/Base64.sol';
import '@openzeppelin/contracts/utils/Context.sol';

// Core contracts of CodeforDAO
import {Share} from './Share.sol';
import {DataTypes} from '../libraries/DataTypes.sol';
import {Errors} from '../libraries/Errors.sol';
import {Events} from '../libraries/Events.sol';

/**
 * @title Membership
 * @notice The Membership Card NFT contract issues the most important part of DAO: membership.
 * This contract is the entry point for all the constituent DAO contracts,
 * and it creates all the subcontracts, including the 2 governance contracts and the vault contract.
 * The indexes of all subcontracts look up the tokenID of this contract
 */
contract Membership is
    Context,
    AccessControlEnumerable,
    Pausable,
    ERC721Enumerable,
    ERC721Burnable,
    ERC721Votes
{
    using Counters for Counters.Counter;
    using Strings for uint256;

    // Governance related contracts
    address public treasury;
    address public governor;
    address public shareToken;
    address public shareGovernor;

    // NFT Membership related states
    /// @dev keccak256('PAUSER_ROLE')
    bytes32 public constant PAUSER_ROLE =
        0x65d7a28e3265b37a6474929f336521b332c1681b933f6cb9f3376673440d862a;
    /// @dev keccak256('INVITER_ROLE')
    bytes32 public constant INVITER_ROLE =
        0x639cc15674e3ab889ef8ffacb1499d6c868345f7a98e2158a7d43d23a757f8e0;

    string private _baseTokenURI;
    string private _contractURI;
    bytes32 private _merkleTreeRoot;
    Counters.Counter private _tokenIdTracker;
    mapping(uint256 => string) private _decentralizedStorage;
    mapping(uint256 => bool) private _isInvestor;

    constructor(
        DataTypes.BaseToken memory membership,
        string memory baseTokenURI,
        string memory contractURI
    ) ERC721(membership.name, membership.symbol) EIP712(membership.name, '1') {
        _baseTokenURI = baseTokenURI;
        _contractURI = contractURI;

        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _grantRole(PAUSER_ROLE, _msgSender());
        _grantRole(INVITER_ROLE, _msgSender());
    }

    /**
     * @dev Returns the DAO's membership token URI
     */
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), Errors.ERC721METADATA_NONEXIST_TOKEN);

        string memory baseURI = _baseURI();

        if (bytes(_decentralizedStorage[tokenId]).length > 0) {
            // TODO: Support for multiple URIs like ar:// or ipfs://
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

    /**
     * @dev Returns if a tokenId is marked as investor
     */
    function isInvestor(uint256 tokenId) public view returns (bool) {
        return _isInvestor[tokenId];
    }

    /**
     * @dev setup governor roles for the DAO
     */
    function setupGovernor(
        address shareTokenAddress,
        address treasuryAddress,
        address governorAddress,
        address shareGovernorAddress
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        // Bind DAO's share token
        shareToken = shareTokenAddress;

        // Bind DAO's Treasury contract
        treasury = treasuryAddress;

        // Bind DAO's 1/1 Membership Governance contract
        governor = governorAddress;

        // Bind DAO's share Governance
        shareGovernor = shareGovernorAddress;
    }

    /**
     * @dev Self-mint for white-listed members
     */
    function mint(bytes32[] calldata proof) public {
        if (balanceOf(_msgSender()) > 0) revert Errors.MembershipAlreadyClaimed();

        if (!MerkleProof.verify(proof, _merkleTreeRoot, keccak256(abi.encodePacked(_msgSender()))))
            revert Errors.InvalidProof();

        // tokenId start with 0
        _mint(_msgSender(), _tokenIdTracker.current());
        _tokenIdTracker.increment();
    }

    /**
     * @dev Treasury could mint for a investor by pass the allowlist check
     */
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

    /**
     * @dev Switch for the use of decentralized storage
     */
    function updateTokenURI(uint256 tokenId, string calldata dataURI) public {
        require(_exists(tokenId), Errors.ERC721METADATA_UPDATE_NONEXIST_TOKEN);
        require(ownerOf(tokenId) == _msgSender(), Errors.ERC721METADATA_UPDATE_UNAUTH);

        _decentralizedStorage[tokenId] = dataURI;
    }

    /**
     * @dev update allowlist by a back-end server bot
     */
    function updateAllowlist(bytes32 merkleTreeRoot_) public {
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

        // @dev Pause status won't block mint operation
        if (from != address(0) && paused()) revert Errors.TokenTransferWhilePaused();
    }

    /**
     * @dev The functions below are overrides required by Solidity.
     */
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
