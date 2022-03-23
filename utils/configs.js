const fs = require('fs');
const { utils } = require('ethers');
const { isAddress, getAddress, formatUnits, parseUnits } = utils;

// At this moment can not get test helper's `time` function working,
// Beacuse of the init parameters is hardcoded,
// To make this test case work, we need to adjust some parameters
// in `Membership.sol` when initializing the contract:
// votingDelay_: 0,
// votingPeriod_: 2,
// proposalThreshold_: 1,
// quorumNumerator_: 3,
// treasury_: new Treasury(1, _proposers, _executors)
module.exports.testArgs = function () {
  return [
    {
      name: 'CodeforDAO',
      symbol: 'CODE',
    },
    {
      name: 'CodeforDAOShare',
      symbol: 'CFD',
    },
    {
      /// @dev for testing purposes only
      timelockDelay: 1,
      share: {
        initialSupply: 1000000,
        initialSplit: {
          members: 20,
          investors: 10,
          market: 30,
          reserved: 40,
        },
        governor: {
          votingDelay: 1000,
          votingPeriod: 10000,
          quorumNumerator: 4,
          proposalThreshold: 100,
        },
      },
      membership: {
        /// @dev: for testing purposes only
        governor: {
          votingDelay: 0,
          votingPeriod: 2,
          quorumNumerator: 3,
          proposalThreshold: 1,
        },
        enableMembershipTransfer: false,
        baseTokenURI: 'https://codefordao.org/member/',
        contractURI: 'https://codefordao.org/membership/',
      },
      investment: {
        enableInvestment: true,
        investThresholdInETH: 1,
        investRatioInETH: 2,
        investInERC20: [],
        investThresholdInERC20: [],
        investRatioInERC20: [],
      },
    },
  ];
};

module.exports.prepareNetworkConfigs = function (networks) {
  const mainnetGwei = 21;
  const currentRelay = process.env.DEFAULT_RELAY || 'infura';
  const hardhatLocalConfig = {
    hardhat: {
      initialBaseFeePerGas: 0,
    },
    localhost: {
      url: 'http://localhost:8545',
    },
  };

  // To use this feature you need to connect to an archive node.
  // At this moment it's hardcoded to alchemy archive code.
  if (process.env.FORK_MAINNET && process.env.ALCHEMY_API_KEY) {
    hardhatLocalConfig.hardhat.forking = {
      url: `https://eth-mainnet.alchemyapi.io/v2/${process.env.ALCHEMY_API_KEY}`,
    };
  }

  return networks.reduce((acc, network) => {
    acc[network] = {
      url: relayURLs(network)[currentRelay],
      accounts: {
        mnemonic: getMnenomic(),
      },
    };

    if (network === 'mainnet') {
      acc[network].gasPrice = mainnetGwei * 1000000000;
    }

    return acc;
  }, hardhatLocalConfig);
};

function relayURLs(network) {
  return {
    infura: `https://${network}.infura.io/v3/${process.env.INFURA_PROJECT_ID}`,
  };
}

function getMnenomic() {
  const filePath = process.env.MNEMONIC_PATH || './mnemonic.txt';

  try {
    return fs.readFileSync(filePath).toString().trim();
  } catch (err) {
    return '';
  }
}
