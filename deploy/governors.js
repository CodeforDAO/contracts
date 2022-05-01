const { testArgs } = require('../utils/configs');

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy, execute } = deployments;
  const { deployer } = await getNamedAccounts();
  const share = await deployments.get('Share');
  const membership = await deployments.get('Membership');
  const treasury = await deployments.get('Treasury');
  const Membership = await ethers.getContract('Membership');
  const settings = testArgs()[2];
  // keccak256('PROPOSER_ROLE')
  const PROPOSER_ROLE = 0xb09aa5aeb3702cfd50b6b62bc4532604938f21248a27a1d5ca736082b6819cc1;
  // keccak256('TIMELOCK_ADMIN_ROLE')
  const TIMELOCK_ADMIN_ROLE = 0x5f58e3a2316349923ce3780f8d587db2d72378aed66a8261c916544fa6846ca5;
  const DEFAULT_ADMIN_ROLE = 0x00;

  const membershipGovernor = await deploy('MembershipGovernor', {
    contract: 'TreasuryGovernor',
    from: deployer,
    args: [
      Membership.name() + '-MembershipGovernor',
      membership.address,
      treasury.address,
      settings.membership.governor,
    ],
    log: true,
  });

  const shareGovernor = await deploy('ShareGovernor', {
    contract: 'TreasuryGovernor',
    from: deployer,
    args: [
      Membership.name() + '-ShareGovernor',
      share.address,
      treasury.address,
      settings.share.governor,
    ],
    log: true,
  });

  // Setup governor roles
  // Both membership and share governance have PROPOSER_ROLE by default
  execute('Treasury', { from: deployer }, 'grantRole', PROPOSER_ROLE, membershipGovernor.address);
  execute('Treasury', { from: deployer }, 'grantRole', PROPOSER_ROLE, shareGovernor.address);

  // Revoke `TIMELOCK_ADMIN_ROLE` from this deployer
  execute('Treasury', { from: deployer }, 'revokeRole', TIMELOCK_ADMIN_ROLE, deployer);

  // Setup governor roles for the DAO
  execute(
    'Membership',
    { from: deployer },
    'setupGovernor',
    share.address,
    treasury.address,
    membershipGovernor.address,
    shareGovernor.address
  );

  // Revoke other roles from this deployer
  // reserved the INVITER_ROLE case we need it to modify the allowlist by a non-admin deployer address.
  execute('Membership', { from: deployer }, 'revokeRole', DEFAULT_ADMIN_ROLE, deployer);
};

module.exports.tags = ['Governors'];
module.exports.dependencies = ['Share', 'Membership', 'Treasury'];
module.exports.runAtTheEnd = true;
