const { testArgs } = require('../utils/configs');

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  await deploy('Membership', {
    from: deployer,
    args: testArgs(),
    log: true,
  });
};

module.exports.tags = ['Membership'];
