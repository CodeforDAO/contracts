const { testArgs } = require('../utils/configs');

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();
  const membership = await deployments.get('Membership');
  const modulePrams = [membership.address, [0, 1], 100];

  await deploy('Payroll', {
    from: deployer,
    args: modulePrams,
    log: true,
  });

  await deploy('Options', {
    from: deployer,
    args: modulePrams,
    log: true,
  });
};

module.exports.tags = ['Modules'];
module.exports.dependencies = ['Membership'];
