const { testArgs } = require('../utils/configs');

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  await deploy('Share', {
    from: deployer,
    args: testArgs()[1],
    log: true,
  });
};

module.exports.tags = ['Share'];
