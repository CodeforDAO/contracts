const { testArgs } = require('../utils/configs');

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();
  const share = await deployments.get('Share');
  const membership = await deployments.get('Membership');
  const treasury = await deployments.get('Treasury');
  const settings = testArgs()[2];

  await deploy('TreasuryGovernor', {
    from: deployer,
    args: [
      membership.name() + '-MembershipGovernor',
      membership.address,
      treasury.address,
      settings.membership.governor,
    ],
    log: true,
  });

  await deploy('TreasuryGovernor', {
    from: deployer,
    args: [
      membership.name() + '-ShareGovernor',
      share.address,
      treasury.address,
      settings.share.governor,
    ],
    log: true,
  });
};

module.exports.tags = ['Governors'];
module.exports.dependencies = ['Share', 'Membership', 'Treasury'];
