//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'hardhat/console.sol';
import '@openzeppelin/contracts/governance/TimelockController.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import '../interfaces/IShare.sol';
import '../interfaces/IMembership.sol';
import {DataTypes} from '../libraries/DataTypes.sol';
import {Errors} from '../libraries/Errors.sol';
import {Events} from '../libraries/Events.sol';

contract Treasury is TimelockController {
    address public share;
    address public membership;
    DataTypes.InvestmentSettings public investmentSettings;

    address[] private _proposers;
    address[] private _executors = [address(0)];
    mapping(address => uint256) private _investThresholdInERC20;
    mapping(address => uint256) private _investRatioInERC20;

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

    function updateInvestmentSettings(DataTypes.InvestmentSettings memory settings) public {
        require(msg.sender == address(this), Errors.CALLER_MUST_BE_SELF);

        investmentSettings = settings;
        _mappingSettings(settings);
    }

    // Invest in ETH
    function invest() external payable investmentEnabled {
        if (investmentSettings.investRatioInETH == 0) revert Errors.InvestmentDisabled();

        if (msg.value < investmentSettings.investThresholdInETH)
            revert Errors.InvestmentThresholdNotMet(investmentSettings.investThresholdInETH);

        _invest(msg.value / investmentSettings.investRatioInETH);
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
        _invest(_allowance / _radio);
    }

    // Transfer share to spec address
    // Mint if thre's not enough share
    // Mint or mark membership NFT also
    function _invest(uint256 _shareTobeClaimed) private {
        uint256 _shareTreasury = IERC20(share).balanceOf(address(this));

        if (_shareTreasury < _shareTobeClaimed) {
            IShare(share).mint(address(this), _shareTobeClaimed - _shareTreasury);
        }

        IERC20(share).transfer(_msgSender(), _shareTobeClaimed);

        emit Events.InvestInETH(_msgSender(), msg.value, _shareTobeClaimed);

        IMembership(membership).investMint(_msgSender());
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
