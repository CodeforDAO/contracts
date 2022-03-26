const { expect } = require('chai');
const { ethers, deployments } = require('hardhat');
const { setupProof, contractsReady } = require('../utils/helpers');

describe('Modules', function () {
  before(async function () {
    await setupProof(this);
  });

  beforeEach(async function () {
    // @dev the order of these deployments is important
    // make sure your custom fixtures are in the last.
    await deployments.fixture(['Modules', 'Mocks']);
    await contractsReady(this, true)();

    this.modules = {
      payroll: await ethers.getContract('Payroll'),
      options: await ethers.getContract('Options'),
    };
    this.receiver = await ethers.getContract('CallReceiverMock');
    // Proposal for testing
    this.proposal = [
      // targets
      [this.receiver.address],
      // value (of ETH)
      [0],
      // calldata
      [this.receiver.interface.encodeFunctionData('mockFunction()', [])],
      // description
      '<proposal description>',
    ];
  });

  describe('deployment check', function () {
    it('Should created with target NAME and DESCRIPTION', async function () {
      expect(await this.modules.payroll.NAME()).to.equal('Payroll');
      expect(await this.modules.payroll.DESCRIPTION()).to.equal('Payroll Module V1');
      expect(await this.modules.options.NAME()).to.equal('Options');
      expect(await this.modules.options.DESCRIPTION()).to.equal('Options Module V1');
    });
  });

  describe('#listOperators', function () {
    it('Should created with target operators', async function () {
      const targetOps = [0, 1].map((n) => ethers.BigNumber.from(n));
      expect(await this.modules.payroll.listOperators()).to.deep.equal(targetOps);
      expect(await this.modules.options.listOperators()).to.deep.equal(targetOps);
    });
  });

  describe('lowlevel module functions', function () {
    it('Should be able to propose by a operator', async function () {
      await expect(this.modules.payroll.propose(...this.proposal)).to.emit(
        this.modules.payroll,
        'ModuleProposalCreated'
      );
    });

    it('Should not be able to propose by unauth account', async function () {
      await expect(
        this.modules.payroll.connect(this.whitelistAccounts[2]).propose(...this.proposal)
      ).to.be.revertedWith('NotOperator()');
    });
  });
});
