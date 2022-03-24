const { expect } = require('chai');
const { ethers, deployments, getNamedAccounts, getUnnamedAccounts } = require('hardhat');
const keccak256 = require('keccak256');
const { MerkleTree } = require('merkletreejs');
const { testArgs } = require('../utils/configs');
const zeroAddres = ethers.constants.AddressZero;
const _args = testArgs();

describe('Module', function () {
  before(async function () {
    const { deployer } = await getNamedAccounts();
    this.accounts = await getUnnamedAccounts();
    this.owner = await ethers.getSigner(deployer);
    this.ownerAddress = deployer;

    // Create a test merkle tree
    const leafNodes = [deployer]
      .concat(this.accounts.filter((_, idx) => idx < 4))
      .map((adr) => keccak256(adr));
    const merkleTree = new MerkleTree(leafNodes, keccak256, {
      sortPairs: true,
    });

    this.rootHash = merkleTree.getHexRoot();
    this.proof = merkleTree.getHexProof(keccak256(this.ownerAddress));
    this.proof2 = merkleTree.getHexProof(keccak256(await this.accounts[1]));
    this.badProof = merkleTree.getHexProof(keccak256(await this.accounts[4]));
  });

  beforeEach(async function () {
    await deployments.fixture(['Modules']);

    this.membership = await ethers.getContract('Membership');
    this.modules = {
      payroll: await ethers.getContract('Payroll'),
      options: await ethers.getContract('Options'),
    };
  });

  describe('deployment check', function () {
    it('Should created with target NAME and DESCRIPTION', async function () {
      expect(await this.modules.payroll.NAME()).to.equal('Payroll');
      expect(await this.modules.payroll.DESCRIPTION()).to.equal('Payroll Module V1');
    });
  });
});
