const keccak256 = require('keccak256');
const { MerkleTree } = require('merkletreejs');
const { deployments, ethers } = require('hardhat');

module.exports.roles = {
  MINTER_ROLE: keccak256('MINTER_ROLE'),
  PAUSER_ROLE: keccak256('PAUSER_ROLE'),
  PROPOSER_ROLE: keccak256('PROPOSER_ROLE'),
  TIMELOCK_ADMIN_ROLE: keccak256('TIMELOCK_ADMIN_ROLE'),
  DEFAULT_ADMIN_ROLE: ethers.constants.HashZero,
};

module.exports.setupProof = async function (context, _index = 4) {
  const { deployer } = await getNamedAccounts();
  const accounts = await getUnnamedAccounts();

  const allowlistAddresses = [deployer].concat(accounts.filter((_, idx) => idx < _index));
  const leafNodes = allowlistAddresses.map((adr) => keccak256(adr));
  const merkleTree = new MerkleTree(leafNodes, keccak256, {
    sortPairs: true,
  });

  const deps = {
    rootHash: merkleTree.getHexRoot(),
    proofs: allowlistAddresses.map((addr) => merkleTree.getHexProof(keccak256(addr))),
    badProof: merkleTree.getHexProof(keccak256(accounts[_index])),
    allowlistAddresses,
    allowlistAccounts: await Promise.all(allowlistAddresses.map((v) => ethers.getSigner(v))),
    accounts,
    owner: await ethers.getSigner(deployer),
    ownerAddress: deployer,
  };

  if (context && typeof context === 'object') {
    Object.keys(deps).forEach((key) => (context[key] = deps[key]));
  }

  return deps;
};

module.exports.contractsReady = function (context, instantMint = false) {
  return deployments.createFixture(async ({ deployments, ethers }, options) => {
    await deployments.fixture();

    const membership = await ethers.getContract('Membership');
    const treasury = await ethers.getContract('Treasury');
    const governor = await ethers.getContract('MembershipGovernor');
    const shareToken = await ethers.getContract('Share');
    const shareGovernor = await ethers.getContract('ShareGovernor');

    if (instantMint) {
      await module.exports.membershipMintAndDelegate(membership, context);
    }

    // Create a test merkle tree
    const deps = {
      membership,
      governor,
      treasury,
      shareGovernor,
      shareToken,
    };

    if (context && typeof context === 'object') {
      Object.keys(deps).forEach((key) => (context[key] = deps[key]));
    }

    return deps;
  });
};

module.exports.membershipMintAndDelegate = async function (membership, context) {
  await membership.updateAllowlist(context.rootHash);

  // Do NOT use `context.allowlistAccounts.forEach` to avoid a block number change
  await Promise.all(
    context.allowlistAccounts.map((account, idx) => {
      return Promise.all([
        membership.connect(account).mint(context.proofs[idx]),
        membership.connect(account).delegate(context.allowlistAddresses[idx]),
      ]);
    })
  );
};

module.exports.findEvent = async function (fn, eventName) {
  const tx = await fn;
  const recipe = await tx.wait();
  return recipe.events.find((e) => e.event === eventName).args;
};

module.exports.isLocalhost = (id) => id == 31337;
