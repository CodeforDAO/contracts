const { testArgs } = require('../utils/configs');

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();
  const membership = await deployments.get('Membership');
  const deployConfig = {
    from: deployer,
    args: [membership.address, [0, 1], 100],
    log: true,
  };

  await deploy('Payroll', deployConfig);
  await deploy('Options', deployConfig);
};

module.exports.tags = ['Modules'];
module.exports.dependencies = ['Membership'];
