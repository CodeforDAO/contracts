const { ethers } = require('hardhat');
const { testArgs } = require('../utils/configs');
const { setupProof, membershipMintAndDelegate, isLocalhost } = require('../utils/helpers');

module.exports = async ({ getNamedAccounts, deployments, getChainId }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();
  const chainId = await getChainId();
  const settings = testArgs()[2];

  await deploy('Membership', {
    from: deployer,
    args: [testArgs()[0], settings.membership.baseTokenURI, settings.membership.contractURI],
    log: true,
  });

  if (isLocalhost(chainId)) {
    const deps = {};
    await setupProof(deps);

    if (process.env.TEST_STAGE === 'MINT_READY') {
      await membershipMintAndDelegate(await ethers.getContract('Membership'), deps);
    }
  }
};

module.exports.tags = ['Membership'];
