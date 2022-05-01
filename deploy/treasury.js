const { testArgs } = require('../utils/configs');

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();
  const share = await deployments.get('Share');
  const membership = await deployments.get('Membership');
  const settings = testArgs()[2];

  await deploy('Treasury', {
    from: deployer,
    args: [settings.timelockDelay, membership.address, share.address, settings.investment],
    log: true,
  });
};

module.exports.tags = ['Treasury'];
module.exports.dependencies = ['Share', 'Membership'];
