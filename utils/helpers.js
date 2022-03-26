const keccak256 = require('keccak256');
const { MerkleTree } = require('merkletreejs');
const { deployments, ethers } = require('hardhat');

module.exports.setupProof = async function (context, _index = 4) {
  const { deployer } = await getNamedAccounts();
  const accounts = await getUnnamedAccounts();

  const whitelistAddresses = [deployer].concat(accounts.filter((_, idx) => idx < _index));
  const leafNodes = whitelistAddresses.map((adr) => keccak256(adr));
  const merkleTree = new MerkleTree(leafNodes, keccak256, {
    sortPairs: true,
  });

  const deps = {
    rootHash: merkleTree.getHexRoot(),
    proofs: whitelistAddresses.map((addr) => merkleTree.getHexProof(keccak256(addr))),
    badProof: merkleTree.getHexProof(keccak256(accounts[_index])),
    whitelistAddresses,
    whitelistAccounts: await Promise.all(whitelistAddresses.map((v) => ethers.getSigner(v))),
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
    await deployments.fixture(['Membership']);

    const Governor = await ethers.getContractFactory('TreasuryGovernor');
    const Treasury = await ethers.getContractFactory('Treasury');

    const membership = await ethers.getContract('Membership');
    const Share = await ethers.getContractFactory('Share');
    const governor = Governor.attach(await membership.governor());

    if (instantMint) {
      await membership.updateWhitelist(context.rootHash);
      await membership.setupGovernor();

      // Do NOT use `context.whitelistAccounts.forEach` to avoid a block number change
      await Promise.all(
        context.whitelistAccounts.map((account, idx) => {
          return Promise.all([
            membership.connect(account).mint(context.proofs[idx]),
            membership.connect(account).delegate(context.whitelistAddresses[idx]),
          ]);
        })
      );
    }

    // Create a test merkle tree
    const deps = {
      membership,
      governor,
      treasury: Treasury.attach(await governor.timelock()),
      shareGovernor: Governor.attach(await membership.shareGovernor()),
      shareToken: Share.attach(await membership.shareToken()),
    };

    if (context && typeof context === 'object') {
      Object.keys(deps).forEach((key) => (context[key] = deps[key]));
    }

    return deps;
  });
};
