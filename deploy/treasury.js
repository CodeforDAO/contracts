const { testArgs } = require('../utils/configs');

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy, execute } = deployments;
  const { deployer } = await getNamedAccounts();
  const share = await deployments.get('Share');
  const membership = await deployments.get('Membership');
  const settings = testArgs()[2];

  // keccak256('MINTER_ROLE');
  const MINTER_ROLE = 0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6;
  const PAUSER_ROLE = 0x65d7a28e3265b37a6474929f336521b332c1681b933f6cb9f3376673440d862a;
  const DEFAULT_ADMIN_ROLE = 0x00;

  const treasury = await deploy('Treasury', {
    from: deployer,
    args: [settings.timelockDelay, membership.address, share.address, settings.investment],
    log: true,
  });

  // Mint initial tokens to the treasury
  if (settings.share.initialSupply > 0) {
    execute('Share', { from: deployer }, 'mint', treasury.address, settings.share.initialSupply);
    execute('Treasury', { from: deployer }, 'updateShareSplit', settings.share.initialSplit);
  }

  // Make sure the DAO's Treasury contract controls everything
  execute('Membership', { from: deployer }, 'grantRole', DEFAULT_ADMIN_ROLE, treasury.address);
  execute('Share', { from: deployer }, 'grantRole', DEFAULT_ADMIN_ROLE, treasury.address);
  execute('Share', { from: deployer }, 'grantRole', MINTER_ROLE, treasury.address);
  execute('Share', { from: deployer }, 'grantRole', PAUSER_ROLE, treasury.address);
  execute('Share', { from: deployer }, 'revokeRole', MINTER_ROLE, deployer);
  execute('Share', { from: deployer }, 'revokeRole', PAUSER_ROLE, deployer);
  execute('Share', { from: deployer }, 'revokeRole', DEFAULT_ADMIN_ROLE, deployer);

  // All membership NFT is set to be non-transferable by default
  if (!settings.membership.enableMembershipTransfer) {
    execute('Membership', { from: deployer }, 'pause');
  }

  // Revoke other roles from this deployer
  // reserved the INVITER_ROLE case we need it to modify the allowlist by a non-admin deployer address.
  execute('Membership', { from: deployer }, 'revokeRole', PAUSER_ROLE, deployer);
  execute('Membership', { from: deployer }, 'revokeRole', DEFAULT_ADMIN_ROLE, deployer);
};

module.exports.tags = ['Treasury'];
module.exports.dependencies = ['Share', 'Membership'];
