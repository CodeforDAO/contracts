const { testArgs } = require('../utils/configs');

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();
  const shareConfigs = testArgs()[1];

  await deploy('Share', {
    from: deployer,
    args: [shareConfigs.name, shareConfigs.symbol],
    log: true,
  });
};

module.exports.tags = ['Share'];
