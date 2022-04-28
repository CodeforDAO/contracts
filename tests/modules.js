const { expect } = require('chai');
const { ethers, deployments } = require('hardhat');
const keccak256 = require('keccak256');
const { setupProof, contractsReady, findEvent } = require('../utils/helpers');

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
    // console.log(this.receiver.address);
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
      // referId,
      keccak256(0),
    ];

    this._payroll = {
      amount: 0,
      paytype: 0,
      period: 0,
      tokens: {
        addresses: [],
        amounts: [],
      },
    };
  });

  describe('deployment check', function () {
    it('Should created with target NAME and DESCRIPTION', async function () {
      expect(await this.modules.payroll.NAME()).to.equal('Payroll');
      expect(await this.modules.payroll.DESCRIPTION()).to.equal('Payroll Module V1');
      expect(await this.modules.options.NAME()).to.equal('Options');
      expect(await this.modules.options.DESCRIPTION()).to.equal('Options Module V1');
    });
  });

  describe('Module functions', function () {
    describe('#listOperators', function () {
      it('Should created with target operators', async function () {
        const targetOps = [0, 1].map((n) => ethers.BigNumber.from(n));
        expect(await this.modules.payroll.listOperators()).to.deep.equal(targetOps);
        expect(await this.modules.options.listOperators()).to.deep.equal(targetOps);
      });
    });

    describe('#propose life cycle', function () {
      it('Should be able to propose by an operator', async function () {
        await expect(this.modules.payroll.propose(...this.proposal)).to.emit(
          this.modules.payroll,
          'ModuleProposalCreated'
        );
      });

      it('Should not be able to propose by unauth account', async function () {
        await expect(
          this.modules.payroll.connect(this.allowlistAccounts[2]).propose(...this.proposal)
        ).to.be.revertedWith('NotOperator()');
      });

      it('Should be able to confirm by an operator', async function () {
        const { id } = await findEvent(
          this.modules.payroll.propose(...this.proposal),
          'ModuleProposalCreated'
        );

        await expect(this.modules.payroll.confirm(id)).to.emit(
          this.modules.payroll,
          'ModuleProposalConfirmed'
        );
      });

      it('Should be able to schedule by an operator', async function () {
        const { id } = await findEvent(
          this.modules.payroll.propose(...this.proposal),
          'ModuleProposalCreated'
        );

        await expect(this.modules.payroll.confirm(id)).to.emit(
          this.modules.payroll,
          'ModuleProposalConfirmed'
        );
        await expect(this.modules.payroll.connect(this.allowlistAccounts[1]).confirm(id)).to.emit(
          this.modules.payroll,
          'ModuleProposalConfirmed'
        );

        await expect(this.modules.payroll.schedule(id)).to.emit(
          this.modules.payroll,
          'ModuleProposalScheduled'
        );
      });

      it('Should be able to execute by an operator', async function () {
        const { id } = await findEvent(
          this.modules.payroll.propose(...this.proposal),
          'ModuleProposalCreated'
        );

        await expect(this.modules.payroll.confirm(id)).to.emit(
          this.modules.payroll,
          'ModuleProposalConfirmed'
        );
        await expect(this.modules.payroll.connect(this.allowlistAccounts[1]).confirm(id)).to.emit(
          this.modules.payroll,
          'ModuleProposalConfirmed'
        );

        await expect(this.modules.payroll.schedule(id)).to.emit(
          this.modules.payroll,
          'ModuleProposalScheduled'
        );

        await expect(this.modules.payroll.execute(id))
          .to.emit(this.modules.payroll, 'ModuleProposalExecuted')
          .to.emit(this.modules.payroll.timelock(), 'CallExecuted')
          .to.emit(this.receiver, 'MockFunctionCalled');
      });
    });
  });

  describe('Payroll', function () {
    it('#addPayroll', async function () {
      await expect(this.modules.payroll.addPayroll(0, this._payroll)).to.emit(
        this.modules.payroll,
        'PayrollAdded'
      );
    });

    it('#getPayroll', async function () {
      await expect(this.modules.payroll.addPayroll(0, this._payroll)).to.emit(
        this.modules.payroll,
        'PayrollAdded'
      );

      const payroll = await this.modules.payroll.getPayroll(0, this._payroll.period);

      expect(payroll[0].amount).to.equal(this._payroll.amount);
    });

    it('#schedulePayroll', async function () {
      const { memberId } = await findEvent(
        this.modules.payroll.addPayroll(0, this._payroll),
        'PayrollAdded'
      );

      await expect(this.modules.payroll.schedulePayroll(memberId, this._payroll.period)).to.emit(
        this.modules.payroll,
        'PayrollScheduled'
      );
    });

    it('Payroll lifecycle', async function () {
      const { memberId } = await findEvent(
        this.modules.payroll.addPayroll(0, this._payroll),
        'PayrollAdded'
      );

      const { proposalId } = await findEvent(
        this.modules.payroll.schedulePayroll(memberId, this._payroll.period),
        'PayrollScheduled'
      );

      await expect(this.modules.payroll.confirm(proposalId)).to.emit(
        this.modules.payroll,
        'ModuleProposalConfirmed'
      );
      await expect(
        this.modules.payroll.connect(this.allowlistAccounts[1]).confirm(proposalId)
      ).to.emit(this.modules.payroll, 'ModuleProposalConfirmed');

      await expect(this.modules.payroll.schedule(proposalId)).to.emit(
        this.modules.payroll,
        'ModuleProposalScheduled'
      );

      await expect(this.modules.payroll.execute(proposalId))
        .to.emit(this.modules.payroll, 'ModuleProposalExecuted')
        .to.emit(this.modules.payroll.timelock(), 'CallExecuted')
        .to.emit(this.modules.payroll, 'PayrollExecuted')
        .withArgs(this.ownerAddress, 0, this._payroll.amount);
    });
  });
});
