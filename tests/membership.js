const { expect } = require('chai');
const { ethers } = require('hardhat');
const { testArgs } = require('../utils/configs');
const { setupProof, contractsReady } = require('../utils/helpers');
const zeroAddres = ethers.constants.AddressZero;
const _args = testArgs();
const _testJSONString = JSON.stringify({
  testKey: 'testKey',
});

describe('Membership', function () {
  before(async function () {
    await setupProof(this);
  });

  beforeEach(async function () {
    await contractsReady(this)();
  });

  describe('deployment check', function () {
    it('Should create a membership governor (1/1) contract', async function () {
      expect(await this.membership.governor()).to.equal(this.governor.address);
    });

    it('Should create a share token (ERC20) contract', async function () {
      expect(await this.membership.shareToken()).to.equal(this.shareToken.address);
      expect(await this.shareToken.name()).to.equal(_args[1].name);
      expect(await this.shareToken.symbol()).to.equal(_args[1].symbol);
    });

    it('Should create a share governor (ERC20 Votes) contract', async function () {
      expect(await this.membership.shareGovernor()).to.equal(this.shareGovernor.address);
    });

    it('Should create a treasury (timelock) contract', async function () {
      expect(await this.governor.timelock()).to.equal(this.treasury.address);
    });

    it('Should has the default admin role of treasury (timelock) contract', async function () {
      expect(
        await this.treasury.hasRole(
          await this.treasury.TIMELOCK_ADMIN_ROLE(),
          this.membership.address
        )
      ).to.equal(true);
    });
  });

  describe('#setupGovernor', function () {
    it('Should not be able to call by a invaid account', async function () {
      await expect(
        this.membership.connect(await ethers.getSigner(this.accounts[1])).setupGovernor()
      ).to.be.revertedWith('is missing role');
    });

    it('Should be able to setup the governor contract roles', async function () {
      await this.membership.setupGovernor();

      // Make sure propose role and execute role are set
      expect(
        await this.treasury.hasRole(await this.treasury.PROPOSER_ROLE(), this.governor.address)
      ).to.equal(true);

      expect(
        await this.treasury.hasRole(await this.treasury.PROPOSER_ROLE(), this.shareGovernor.address)
      ).to.equal(true);

      expect(await this.treasury.hasRole(await this.treasury.EXECUTOR_ROLE(), zeroAddres)).to.equal(
        true
      );

      // The init timelock admin role should be set to false
      expect(
        await this.treasury.hasRole(
          await this.treasury.TIMELOCK_ADMIN_ROLE(),
          this.membership.address
        )
      ).to.equal(false);

      // Membership contract's default admin role should be treasury (timelock) contract
      expect(
        await this.membership.hasRole(
          await this.membership.DEFAULT_ADMIN_ROLE(),
          this.treasury.address
        )
      ).to.equal(true);

      // Make sure the share token has right roles
      expect(
        await this.shareToken.hasRole(
          await this.shareToken.DEFAULT_ADMIN_ROLE(),
          this.treasury.address
        )
      ).to.equal(true);
      expect(
        await this.shareToken.hasRole(await this.shareToken.MINTER_ROLE(), this.treasury.address)
      ).to.equal(true);
      expect(
        await this.shareToken.hasRole(await this.shareToken.PAUSER_ROLE(), this.treasury.address)
      ).to.equal(true);
      expect(
        await this.shareToken.hasRole(
          await this.shareToken.DEFAULT_ADMIN_ROLE(),
          this.membership.address
        )
      ).to.equal(false);
      expect(
        await this.shareToken.hasRole(await this.shareToken.MINTER_ROLE(), this.membership.address)
      ).to.equal(false);
      expect(
        await this.shareToken.hasRole(await this.shareToken.PAUSER_ROLE(), this.membership.address)
      ).to.equal(false);

      // Make sure initialSupply is minted
      expect(await this.shareToken.balanceOf(this.treasury.address)).to.equal(
        _args[2].share.initialSupply
      );

      // Make sure token transfer is paused by default
      expect(await this.membership.paused()).to.equal(
        !_args[2].membership.enableMembershipTransfer
      );

      // Deployer's role should be revoked
      expect(
        await this.membership.hasRole(await this.membership.PAUSER_ROLE(), this.ownerAddress)
      ).to.equal(false);
      expect(
        await this.membership.hasRole(await this.membership.DEFAULT_ADMIN_ROLE(), this.ownerAddress)
      ).to.equal(false);
    });
  });

  describe('#updateAllowlist', function () {
    it('Should not updated by invalid account', async function () {
      await expect(
        this.membership
          .connect(await ethers.getSigner(this.accounts[1]))
          .updateAllowlist(this.rootHash)
      ).to.be.revertedWith('NotInviter()');
    });
  });

  describe('#mint', function () {
    it('Should able to mint NFT for account in allowlist', async function () {
      await this.membership.updateAllowlist(this.rootHash);
      await expect(this.membership.mint(this.proofs[0]))
        .to.changeTokenBalance(this.membership, this.ownerAddress, 1)
        .to.emit(this.membership, 'Transfer')
        .withArgs(zeroAddres, this.ownerAddress, 0);
    });

    it('Should not able to mint NFT for an account more than once', async function () {
      await this.membership.updateAllowlist(this.rootHash);
      await this.membership.mint(this.proofs[0]);

      await expect(this.membership.mint(this.proofs[0])).to.be.revertedWith(
        'MembershipAlreadyClaimed()'
      );
    });

    it('Should not able to mint NFT for account in allowlist with badProof', async function () {
      await this.membership.updateAllowlist(this.rootHash);

      await expect(this.membership.mint(this.badProof)).to.be.revertedWith('InvalidProof()');
    });

    it('Should not able to mint NFT for account not in allowlist', async function () {
      await this.membership.updateAllowlist(this.rootHash);

      await expect(
        this.membership.connect(await ethers.getSigner(this.accounts[4])).mint(this.badProof)
      ).to.be.revertedWith('InvalidProof()');
    });
  });

  describe('#tokenURI', function () {
    it('Should return a server-side token URI by default', async function () {
      await this.membership.updateAllowlist(this.rootHash);
      await this.membership.mint(this.proofs[0]);

      // Notice: hard code tokenId(0) here
      expect(await this.membership.tokenURI(0)).to.equal(`${_args[2].membership.baseTokenURI}0`);
    });

    it('Should return a decentralized token URI after updated', async function () {
      await this.membership.updateAllowlist(this.rootHash);
      await this.membership.mint(this.proofs[0]);
      await this.membership.updateTokenURI(0, _testJSONString);

      // Notice: hard code tokenId(0) here
      expect(await this.membership.tokenURI(0)).to.equal(
        `data:application/json;base64,${Buffer.from(_testJSONString).toString('base64')}`
      );
    });
  });

  describe('#pause', function () {
    it('Should not able to transfer tokens after paused', async function () {
      await this.membership.updateAllowlist(this.rootHash);
      await this.membership.mint(this.proofs[0]);
      await this.membership.pause();

      await expect(
        this.membership.transferFrom(this.ownerAddress, await this.accounts[1], 0)
      ).to.be.revertedWith('TokenTransferWhilePaused()');
    });

    it('Should able to mint tokens even after paused', async function () {
      await this.membership.updateAllowlist(this.rootHash);
      await this.membership.mint(this.proofs[0]);
      await this.membership.pause();
      await this.membership.connect(this.allowlistAccounts[1]).mint(this.proofs[1]);

      // Notice: hard code tokenId(1) here
      expect(await this.membership.balanceOf(this.allowlistAddresses[1])).to.equal(1);
      expect(await this.membership.ownerOf(1)).to.equal(await this.allowlistAddresses[1]);
    });
  });
});
