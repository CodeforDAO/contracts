const { expect } = require('chai');
const { ethers, deployments } = require('hardhat');
const { setupProof, contractsReady } = require('../utils/helpers');

describe('Treasury', function () {
  before(async function () {
    await setupProof(this);
  });

  beforeEach(async function () {
    await contractsReady(this, true)();
  });

  describe('deployment check', function () {
    it('Should created with related contracts', async function () {
      expect(await this.treasury.share()).to.equal(await this.membership.shareToken());
      expect(await this.treasury.membership()).to.equal(this.membership.address);
    });
  });
});
