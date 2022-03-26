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
 * @notice The treasury is one of the core contracts of the DAO and is responsible for managing all of the DAO's assets,
 * including external assets, eth and share tokens of the DAO.
 * the treasury supports external investors in invoking the investment method to self-serve share tokens,
 * and the treasury provides a hook method for modules to pull payments,
 * allowing authorization for some of the assets of the modules used by the DAO.
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

    /**
     * @dev Shortcut method
     * Allows distribution of shares to members in corresponding proportions (index is tokenID)
     * must be called by the timelock itself (requires a voting process)
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
     * @dev Shortcut method
     * to update settings for investment (requires a voting process)
     */
    function updateInvestmentSettings(DataTypes.InvestmentSettings memory settings)
        public
        onlyRole(TIMELOCK_ADMIN_ROLE)
    {
        investmentSettings = settings;
        _mappingSettings(settings);
    }

    /**
     * @dev Shortcut method
     * to update share split (requires a voting process)
     */
    function updateShareSplit(DataTypes.ShareSplit memory _shareSplit)
        public
        onlyRole(TIMELOCK_ADMIN_ROLE)
    {
        shareSplit = _shareSplit;
    }

    /**
     * @dev Invest in ETH
     * Allows external investors to transfer to ETH for investment.
     * ETH will issue share token of DAO at a set rate
     */
    function invest() external payable investmentEnabled {
        if (investmentSettings.investRatioInETH == 0) revert Errors.InvestmentDisabled();

        if (msg.value < investmentSettings.investThresholdInETH)
            revert Errors.InvestmentThresholdNotMet(investmentSettings.investThresholdInETH);

        _invest(msg.value / investmentSettings.investRatioInETH, address(0), msg.value);
    }

    /**
     * @dev Invest in ERC20 tokens
     * External investors are allowed to invest in ERC20,
     * which is issued as a DAO share token at a set rate.
     * @notice Before calling this method, the approve method of the corresponding ERC20 contract must be called.
     */
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

    /**
     * @dev Pull module payment
     * The DAO module pulls the required eth and ERC20 token
     * @notice Need to ensure that the number of authorizations is greater than the required number before pulling.
     * this method is usually required by the module designer,
     * and the method checks whether the module is mounted on the same DAO
     */
    function pullModulePayment(
        uint256 eth,
        address[] calldata tokens,
        uint256[] calldata amounts
    ) public {
        if (tokens.length != amounts.length) revert Errors.InvalidTokenAmounts();

        address moduleAddress = _msgSender();
        if (IModule(moduleAddress).membership() != membership) revert Errors.NotMember();

        DataTypes.ModulePayment storage _payments = _modulePayments[moduleAddress];
        address _timelock = address(IModule(moduleAddress).timelock());
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

    /**
     * @dev Approve module payment
     * Authorize a module to use the corresponding eth and ERC20 token
     */
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
            _token.approve(address(IModule(moduleAddress).timelock()), amounts[i]);
        }

        emit Events.ModulePaymentApproved(moduleAddress, eth, tokens, amounts, block.timestamp);
    }

    /**
     * @dev Private method of realizing external investments
     * The converted share token is automatically transferred to the external investor,
     * and if there are not enough shares in the vault, additional shares are automatically issued.
     * At the same time, the act of investing will mint a new investor status NFT membership card,
     * ensuring that the investor can participate in the voting of board members (1/1 NFT Votes).
     */
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

    // @dev mapping arrays to maps cause of the lack of support of params mapping in Solidity
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
