//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'hardhat/console.sol';
import '@openzeppelin/contracts/governance/TimelockController.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC721/IERC721.sol';

import '../interfaces/IShare.sol';
import '../interfaces/IMembership.sol';
import {DataTypes} from '../libraries/DataTypes.sol';
import {Errors} from '../libraries/Errors.sol';
import {Events} from '../libraries/Events.sol';

contract Treasury is TimelockController {
    address public share;
    address public membership;
    DataTypes.ShareSplit public shareSplit;
    DataTypes.InvestmentSettings public investmentSettings;

    address[] private _proposers;
    address[] private _executors = [address(0)];
    mapping(address => uint256) private _investThresholdInERC20;
    mapping(address => uint256) private _investRatioInERC20;
    bytes32 private constant _TIMELOCK_ADMIN_ROLE = keccak256('TIMELOCK_ADMIN_ROLE');

    constructor(
        uint256 timelockDelay,
        address membershipTokenAddress,
        address shareTokenAddress,
        DataTypes.InvestmentSettings memory settings
    ) TimelockController(timelockDelay, _proposers, _executors) {
        membership = membershipTokenAddress;
        share = shareTokenAddress;
        investmentSettings = settings;

        if (settings.investInERC20.length > 0) {
            for (uint256 i = 0; i < settings.investInERC20.length; i++) {
                address _token = settings.investInERC20[i];
                _investThresholdInERC20[_token] = settings.investThresholdInERC20[i];
                _investRatioInERC20[_token] = settings.investRatioInERC20[i];
            }
        }
    }

    modifier investmentEnabled() {
        if (!investmentSettings.enableInvestment) revert Errors.InvestmentDisabled();
        _;
    }

    function updateShareSplit(DataTypes.ShareSplit memory _shareSplit)
        public
        onlyRole(_TIMELOCK_ADMIN_ROLE)
    {
        shareSplit = _shareSplit;
    }

    // Vesting share for members as given ratio
    function vestingShare(uint256[] calldata tokenId, uint8[] calldata shareRatio)
        public
        onlyRole(_TIMELOCK_ADMIN_ROLE)
    {
        uint256 _shareTreasury = IERC20(share).balanceOf(address(this));

        if (_shareTreasury == 0) revert Errors.NoShareInTreasury();

        uint256 _membersShare = _shareTreasury * (shareSplit.members / 100);

        if (_membersShare == 0) revert Errors.NoMembersShareToVest();

        for (uint256 i = 0; i < tokenId.length; i++) {
            address _member = IERC721(membership).ownerOf(tokenId[i]);
            IERC20(share).transfer(_member, (_membersShare * shareRatio[i]) / 100);
        }
    }

    function updateInvestmentSettings(DataTypes.InvestmentSettings memory settings)
        public
        onlyRole(_TIMELOCK_ADMIN_ROLE)
    {
        investmentSettings = settings;
        _mappingSettings(settings);
    }

    // Invest in ETH
    function invest() external payable investmentEnabled {
        if (investmentSettings.investRatioInETH == 0) revert Errors.InvestmentDisabled();

        if (msg.value < investmentSettings.investThresholdInETH)
            revert Errors.InvestmentThresholdNotMet(investmentSettings.investThresholdInETH);

        _invest(msg.value / investmentSettings.investRatioInETH, address(0), msg.value);
    }

    // Must approve() spec amount before calling this function
    function investInERC20(address token) external investmentEnabled {
        if (_investRatioInERC20[token] == 0) revert Errors.InvestmentInERC20Disabled(token);

        uint256 _radio = _investRatioInERC20[token];

        if (_radio == 0) revert Errors.InvestmentInERC20Disabled(token);

        uint256 _threshold = _investThresholdInERC20[token];
        uint256 _allowance = IERC20(token).allowance(_msgSender(), address(this));

        if (_allowance < _threshold)
            revert Errors.InvestmentInERC20ThresholdNotMet(token, _threshold);

        IERC20(token).transferFrom(_msgSender(), address(this), _allowance);
        _invest(_allowance / _radio, token, _allowance);
    }

    // Transfer share to spec address
    // Mint if thre's not enough share
    // Mint or mark membership NFT also
    function _invest(
        uint256 _shareTobeClaimed,
        address _token,
        uint256 _amount
    ) private {
        uint256 _shareTreasury = IERC20(share).balanceOf(address(this));

        if (_shareTreasury < _shareTobeClaimed) {
            IShare(share).mint(address(this), _shareTobeClaimed - _shareTreasury);
        }

        IERC20(share).transfer(_msgSender(), _shareTobeClaimed);
        IMembership(membership).investMint(_msgSender());

        if (_token == address(0)) {
            emit Events.InvestInETH(_msgSender(), msg.value, _shareTobeClaimed);
        } else {
            emit Events.InvestInERC20(_msgSender(), _token, _amount, _shareTobeClaimed);
        }
    }

    function _mappingSettings(DataTypes.InvestmentSettings memory settings) private {
        if (settings.investInERC20.length > 0) {
            for (uint256 i = 0; i < settings.investInERC20.length; i++) {
                address _token = settings.investInERC20[i];
                _investThresholdInERC20[_token] = settings.investThresholdInERC20[i];
                _investRatioInERC20[_token] = settings.investRatioInERC20[i];
            }
        }
    }
}
