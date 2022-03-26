const { expect } = require('chai');
const { ethers, deployments } = require('hardhat');
const { setupProof, contractsReady } = require('../utils/helpers');

describe('Module', function () {
  before(async function () {
    await setupProof(this);
  });

  beforeEach(async function () {
    await contractsReady(this)();
    await deployments.fixture(['Modules']);

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
