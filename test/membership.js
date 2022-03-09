const { expect } = require("chai")
const { ethers } = require("hardhat")
const { MerkleTree } = require('merkletreejs');
const keccak256 = require('keccak256');
const zeroAddres = ethers.constants.AddressZero;

const _baseURI = 'http://localhost:3000/NFT/'
const _testJSONString = JSON.stringify({
  testKey: "testKey"
})

describe("Membership", function () {
  before(async function () {
    this.accounts = await ethers.getSigners()
    this.owner = this.accounts[0]
    this.ownerAddress = await this.owner.getAddress()

    // Create a test merkle tree
    const leafNodes = (await Promise.all(this.accounts.filter((_, idx) => idx < 4)
      .map(account => account.getAddress()))).map(adr => keccak256(adr));
    const merkleTree = new MerkleTree(leafNodes, keccak256, { 
      sortPairs: true, 
    });

    this.rootHash = merkleTree.getHexRoot()
    this.proof = merkleTree.getHexProof(keccak256(this.ownerAddress))
    this.proof2 = merkleTree.getHexProof(keccak256(await this.accounts[1].getAddress()))
    this.badProof = merkleTree.getHexProof(keccak256(await this.accounts[4].getAddress()))
  })

  beforeEach(async function () {
    // Deploy Membership contract
    const Membership = await ethers.getContractFactory("Membership")
    const Governor = await ethers.getContractFactory("MembershipGovernor")
    const Treasury = await ethers.getContractFactory("Treasury")

    this.membership = await Membership.deploy(
      'CodeforDAO',
      'CODE',
      _baseURI,
    )

    await this.membership.deployed()

    this.governor = Governor.attach(await this.membership.governor())
    this.treasury = Treasury.attach(await this.governor.timelock())
  })

  describe("deployment check", function () {
    it("Should create a governor contract", async function () {
      expect(await this.membership.governor()).to.equal(this.governor.address)
    })

    it("Should create a treasury (timelock) contract", async function () {
      expect(await this.governor.timelock()).to.equal(this.treasury.address)
    })

    it("Should has the default admin role of treasury (timelock) contract", async function () {
      expect(await this.treasury.hasRole(
        await this.treasury.TIMELOCK_ADMIN_ROLE(),
        this.membership.address,
      )).to.equal(true)
    })
  })

  describe("#setupGovernor", function () {
    it("Should be able to setup the governor contract roles", async function () {
      await this.membership.setupGovernor()

      expect(await this.treasury.hasRole(
        await this.treasury.PROPOSER_ROLE(),
        this.governor.address,
      )).to.equal(true)

      expect(await this.treasury.hasRole(
        await this.treasury.EXECUTOR_ROLE(),
        zeroAddres,
      )).to.equal(true)

      // The init timelock admin role should be set to false
      expect(await this.treasury.hasRole(
        await this.treasury.TIMELOCK_ADMIN_ROLE(),
        this.membership.address,
      )).to.equal(false)

      // Membership contract's default admin role should be treasury (timelock) contract
      expect(await this.membership.hasRole(
        await this.membership.DEFAULT_ADMIN_ROLE(),
        this.treasury.address,
      )).to.equal(true)

      // deployer's role should be revoked
      expect(await this.membership.hasRole(
        await this.membership.DEFAULT_ADMIN_ROLE(),
        this.ownerAddress,
      )).to.equal(false)
    })
  })

  describe("#updateRoot", function () {
    it("Should updated by INVITER_ROLE", async function () {
      await this.membership.updateRoot(this.rootHash)
      expect(await this.membership.merkleTreeRoot()).to.equal(this.rootHash)
    })

    it("Should not updated by invalid account", async function () {
      await expect(this.membership.connect(this.accounts[1]).updateRoot(this.rootHash))
        .to.be.revertedWith('CodeforDAO Membership: must have inviter role to update root')
    })
  })

  describe("#mint", function () {
    it("Should able to mint NFT for account in whitelist", async function () {
      await this.membership.updateRoot(this.rootHash)
      await expect(this.membership.mint(this.proof))
        .to.changeTokenBalance(this.membership, this.ownerAddress, 1)
        .to.emit(this.membership, 'Transfer')
        .withArgs(zeroAddres, this.ownerAddress, 0)
    })

    it("Should not able to mint NFT for an account more than once", async function () {
      await this.membership.updateRoot(this.rootHash)
      await this.membership.mint(this.proof)

      await expect(this.membership.mint(this.proof))
        .to.be.revertedWith('CodeforDAO Membership: address already claimed')
    })

    it("Should not able to mint NFT for account in whitelist with badProof", async function () {
      await this.membership.updateRoot(this.rootHash)

      await expect(this.membership.mint(this.badProof))
        .to.be.revertedWith('CodeforDAO Membership: Invalid proof')
    })

    it("Should not able to mint NFT for account not in whitelist", async function () {
      await this.membership.updateRoot(this.rootHash)

      await expect(this.membership.connect(this.accounts[4]).mint(this.badProof))
        .to.be.revertedWith('CodeforDAO Membership: Invalid proof')
    })
  })

  describe("#tokenURI", function () {
    it("Should return a server-side token URI by default", async function () {
      await this.membership.updateRoot(this.rootHash)
      await this.membership.mint(this.proof)

      // Notice: hard code tokenId(0) here
      expect(await this.membership.tokenURI(0)).to.equal(`${_baseURI}0`)
    })

    it("Should return a decentralized token URI after updated", async function () {
      await this.membership.updateRoot(this.rootHash)
      await this.membership.mint(this.proof)
      await this.membership.updateTokenURI(0, _testJSONString)

      // Notice: hard code tokenId(0) here
      expect(await this.membership.tokenURI(0)).to.equal(`data:application/json;base64,${Buffer.from(_testJSONString).toString('base64')}`)
    })
  })

  describe("#pause", function () {
    it("Should not able to transfer tokens after paused", async function () {
      await this.membership.updateRoot(this.rootHash)
      await this.membership.mint(this.proof)
      await this.membership.pause()

      await expect(this.membership.transferFrom(
        this.ownerAddress,
        await this.accounts[1].getAddress(),
        0,
      )).to.be.revertedWith('CodeforDAO: token transfer while paused')
    })

    it("Should able to mint tokens even after paused", async function () {
      await this.membership.updateRoot(this.rootHash)
      await this.membership.mint(this.proof)
      await this.membership.pause()
      await this.membership.connect(this.accounts[1])
        .mint(this.proof2)

      // Notice: hard code tokenId(1) here
      expect(await this.membership.balanceOf(this.accounts[1].getAddress())).to.equal(1)
      expect(await this.membership.ownerOf(1)).to.equal(await this.accounts[1].getAddress())
    })
  })
})
