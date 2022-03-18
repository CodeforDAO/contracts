//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'hardhat/console.sol';
import '@openzeppelin/contracts/governance/TimelockController.sol';
import '@openzeppelin/contracts/utils/Multicall.sol';
import '@openzeppelin/contracts/utils/Address.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {IShare} from '../interfaces/IShare.sol';
import {IMembership} from '../interfaces/IMembership.sol';
import {IModule} from '../interfaces/IModule.sol';
import {DataTypes} from '../libraries/DataTypes.sol';
import {Errors} from '../libraries/Errors.sol';
import {Events} from '../libraries/Events.sol';

/**
 * @title Treasury
 * @notice The treasury is one of the core contracts of the DAO and is responsible for managing all of the DAO's assets, including external assets, eth and share tokens of the DAO. the treasury supports external investors in invoking the investment method to self-serve share tokens, and the treasury provides a hook method for modules to pull payments, allowing authorization for some of the assets of the modules used by the DAO.
 */
contract Treasury is TimelockController, Multicall {
    using Address for address payable;

    address public immutable share;
    address public immutable membership;
    DataTypes.ShareSplit public shareSplit;
    DataTypes.InvestmentSettings public investmentSettings;

    address[] private _proposers;
    address[] private _executors = [address(0)];
    mapping(address => uint256) private _investThresholdInERC20;
    mapping(address => uint256) private _investRatioInERC20;
    mapping(address => DataTypes.ModulePayment) private _modulePayments;

    constructor(
        uint256 timelockDelay,
        address membershipTokenAddress,
        address shareTokenAddress,
        DataTypes.InvestmentSettings memory settings
    ) TimelockController(timelockDelay, _proposers, _executors) {
        membership = membershipTokenAddress;
        share = shareTokenAddress;
        investmentSettings = settings;
        _mappingSettings(settings);
    }

    modifier investmentEnabled() {
        if (!investmentSettings.enableInvestment) revert Errors.InvestmentDisabled();
        _;
    }

    function pullModulePayment(
        uint256 eth,
        address[] calldata tokens,
        uint256[] calldata amounts
    ) public {
        if (tokens.length != amounts.length) revert Errors.InvalidTokenAmounts();

        address moduleAddress = _msgSender();
        if (IModule(moduleAddress).membership() != membership) revert Errors.NotMember();

        DataTypes.ModulePayment storage _payments = _modulePayments[moduleAddress];
        address _timelock = IModule(moduleAddress).timelock();
        address payable _target = payable(_timelock);

        if (!_payments.approved) revert Errors.ModuleNotApproved();

        if (eth > 0) {
            if (eth > _payments.eth) revert Errors.NotEnoughETH();
            _payments.eth -= eth;
            _target.sendValue(eth);
        }

        for (uint256 i = 0; i < tokens.length; i++) {
            IERC20 _token = IERC20(tokens[i]);
            if (_token.allowance(address(this), _timelock) < amounts[i])
                revert Errors.NotEnoughTokens();

            _token.transferFrom(address(this), _timelock, amounts[i]);
            _payments.erc20[tokens[i]] -= amounts[i];
        }

        emit Events.ModulePaymentPulled(moduleAddress, eth, tokens, amounts, block.timestamp);
    }

    function approveModulePayment(
        address moduleAddress,
        uint256 eth,
        address[] calldata tokens,
        uint256[] calldata amounts
    ) public onlyRole(TIMELOCK_ADMIN_ROLE) {
        if (tokens.length != amounts.length) revert Errors.InvalidTokenAmounts();
        if (IModule(moduleAddress).membership() != membership) revert Errors.NotMember();

        DataTypes.ModulePayment storage _payments = _modulePayments[moduleAddress];

        _payments.approved = true;
        _payments.eth = eth;

        for (uint256 i = 0; i < tokens.length; i++) {
            IERC20 _token = IERC20(tokens[i]);
            if (_token.balanceOf(address(this)) < amounts[i]) revert Errors.NotEnoughTokens();

            _payments.erc20[tokens[i]] = amounts[i];
            _token.approve(IModule(moduleAddress).timelock(), amounts[i]);
        }

        emit Events.ModulePaymentApproved(moduleAddress, eth, tokens, amounts, block.timestamp);
    }

    /**
     * @dev A shortcut function for vesting share to members as given ratio.
     */
    function vestingShare(uint256[] calldata tokenId, uint8[] calldata shareRatio)
        public
        onlyRole(TIMELOCK_ADMIN_ROLE)
    {
        uint256 _shareTreasury = IShare(share).balanceOf(address(this));

        if (_shareTreasury == 0) revert Errors.NoShareInTreasury();

        uint256 _membersShare = _shareTreasury * (shareSplit.members / 100);

        if (_membersShare == 0) revert Errors.NoMembersShareToVest();

        for (uint256 i = 0; i < tokenId.length; i++) {
            address _member = IMembership(membership).ownerOf(tokenId[i]);
            IShare(share).transfer(_member, (_membersShare * shareRatio[i]) / 100);
        }
    }

    /**
     * @dev A shortcut function to update settings for investment
     */
    function updateInvestmentSettings(DataTypes.InvestmentSettings memory settings)
        public
        onlyRole(TIMELOCK_ADMIN_ROLE)
    {
        investmentSettings = settings;
        _mappingSettings(settings);
    }

    /**
     * @dev A shortcut function to update shareSplit.
     */
    function updateShareSplit(DataTypes.ShareSplit memory _shareSplit)
        public
        onlyRole(TIMELOCK_ADMIN_ROLE)
    {
        shareSplit = _shareSplit;
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
        uint256 _allowance = IShare(token).allowance(_msgSender(), address(this));

        if (_allowance < _threshold)
            revert Errors.InvestmentInERC20ThresholdNotMet(token, _threshold);

        IShare(token).transferFrom(_msgSender(), address(this), _allowance);
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
        uint256 _shareTreasury = IShare(share).balanceOf(address(this));

        if (_shareTreasury < _shareTobeClaimed) {
            IShare(share).mint(address(this), _shareTobeClaimed - _shareTreasury);
        }

        IShare(share).transfer(_msgSender(), _shareTobeClaimed);
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
