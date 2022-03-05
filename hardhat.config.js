require("dotenv").config()

const fs = require("fs")
const { utils } = require("ethers")
const { isAddress, getAddress, formatUnits, parseUnits } = utils

require("@nomiclabs/hardhat-waffle")
require("hardhat-deploy")
require("@nomiclabs/hardhat-ethers")
require("hardhat-gas-reporter")
require("@nomiclabs/hardhat-etherscan")
require("@tenderly/hardhat-tenderly")

// Hardhat Tasks
task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
function prepareHardhatConfigs() {
  function relayURLs(network) {
    return {
      'infura': `https://${network}.infura.io/v3/${process.env.INFURA_PROJECT_ID}`,
    }
  }

  function getMnenomic() {
    const filePath = process.env.MNEMONIC_PATH || './mnemonic.txt'

    try {
      return fs.readFileSync(filePath).toString().trim();
    } catch (err) {
      return ''
    }
  }

  function prepareNetworkConfigs() {
    const currentRelay = process.env.DEFAULT_RELAY || 'infura'
    const mainnetGwei = 21
    const ethNetworks = [
      'mainnet',
      'rinkeby',
      'kovan',
      'ropsten',
      'goerli',
    ]
    const hardhatLocalConfig = {
      hardhat: {}
    }

    // To use this feature you need to connect to an archive node.
    // At this moment it's hardcoded to alchemy archive code.
    if (process.env.FORK_MAINNET &&
      process.env.ALCHEMY_API_KEY) {
      hardhatLocalConfig.hardhat.forking = {
        url: `https://eth-mainnet.alchemyapi.io/v2/${process.env.ALCHEMY_API_KEY}`,
      }
    }

    return ethNetworks.reduce((acc, network) => {
      acc[network] = {
        url: relayURLs(network)[currentRelay],
        accounts: {
          mnemonic: getMnenomic(),
        },
      }

      if (network === 'mainnet') {
        acc[network].gasPrice = mainnetGwei * 1000000000
      }

      return acc
    }, hardhatLocalConfig)
  }

  // The hardhat config object will be returned.
  const config = {
    networks: prepareNetworkConfigs(),
    solidity: {
      version: "0.8.4",
      settings: {
        optimizer: {
          enabled: true,
          runs: 200,
        },
      }
    },

    /**
     * gas reporter configuration that let's you know
     * an estimate of gas for contract deployments and function calls
     * More here: https://www.npmjs.com/package/hardhat-gas-reporter
     */
    gasReporter: {
      currency: "USD",
      enabled: !!process.env.REPORT_GAS,
    }
  }

  // Hardhat plugin for integration with Tenderly. 
  // This plugin adds `tenderly:verify` task and `tenderly:push` task to Hardhat.
  // To use this plugin, you will need to exec `tenderly login` first on the `tenderly-cli`
  // More here: https://www.npmjs.com/package/@tenderly/hardhat-tenderly
  if (process.env.TENDERLY_PROJECT_ID &&
    process.env.TENDERLY_USERNAME) {
    config.tenderly = {
      project: process.env.TENDERLY_PROJECT_ID,
      username: process.env.TENDERLY_USERNAME,
    }
  }

  // Hardhat plugin for integration with Etherscan's contract verification service. 
  // Provides the verify task, which allows you to verify contracts through Etherscan's service.
  if (process.env.ETHERSCAN_API_KEY) {
    config.etherscan = {
      apiKey: process.env.ETHERSCAN_API_KEY,
    }
  }

  return config
}

module.exports = prepareHardhatConfigs()