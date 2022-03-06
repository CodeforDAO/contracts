const { expect } = require("chai")
const { ethers } = require("hardhat")
const { MerkleTree } = require('merkletreejs');
const keccak256 = require('keccak256');

describe("Membership", function () {
  const _baseURI = 'http://localhost:3000/NFT'
  let Membership, Governor, Treasury, membership, governor, treasury, accounts, owner, rootHash, proof, badProof;

  before(async function () {
    accounts = await ethers.getSigners()
    owner = accounts[0]

    // Create a test merkle tree
    const leafNodes = (await Promise.all(accounts.filter((_, idx) => idx < 4)
      .map(account => account.getAddress()))).map(adr => keccak256(adr));
    const merkleTree = new MerkleTree(leafNodes, keccak256, { 
      sortPairs: true, 
    });
    rootHash = merkleTree.getHexRoot()
    proof = merkleTree.getHexProof(keccak256(await owner.getAddress()))
    badProof = merkleTree.getHexProof(keccak256(await accounts[4].getAddress()))
  })

  beforeEach(async function () {
    // Deploy Membership contract
    Membership = await ethers.getContractFactory("Membership")
    Governor = await ethers.getContractFactory("MembershipGovernor")
    Treasury = await ethers.getContractFactory("Treasury")
    membership = await Membership.deploy(
      'CodeforDAO',
      'CODE',
      _baseURI,
    )

    await membership.deployed()

    const governorAddress = await membership.governor()
    governor = Governor.attach(governorAddress)

    const timelockAddress = await governor.timelock()
    treasury = Treasury.attach(timelockAddress)
  })

  describe("#constructor", function () {
    it("Should create a governor contract", async function () {
      expect(await membership.governor()).to.equal(governor.address)
    })

    it("Should create a treasury (timelock) contract", async function () {
      expect(await governor.timelock()).to.equal(treasury.address)
    })
  })

  describe("#updateRoot", function () {
    it("Should updated by INVITER_ROLE", async function () {
      await membership.updateRoot(rootHash)
      expect(await membership.merkleTreeRoot()).to.equal(rootHash)
    })

    it("Should not updated by unvalid account", async function () {
      try {
        await membership.connect(accounts[1]).updateRoot(rootHash)
      } catch (err) {
        expect(err.message).to.have.string('CodeforDAO Membership: must have inviter role to update root')
      }
    })
  })

  describe("#mint", function () {
    it("Should able to mint NFT for account in whitelist", async function () {
      await membership.updateRoot(rootHash)
      await membership.mint(proof)

      expect(await membership.balanceOf(owner.getAddress())).to.equal(1)
    })

    it("Should not able to mint NFT for an account more than once", async function () {
      await membership.updateRoot(rootHash)
      await membership.mint(proof)

      try {
        await membership.mint(proof)
      } catch (err) {
        expect(err.message).to.have.string('CodeforDAO Membership: address already claimed')
      }
    })

    it("Should not able to mint NFT for account in whitelist with badProof", async function () {
      await membership.updateRoot(rootHash)

      try {
        await membership.mint(badProof)
      } catch (err) {
        expect(err.message).to.have.string('CodeforDAO Membership: Invalid proof')
      }
    })

    it("Should not able to mint NFT for account not in whitelist", async function () {
      await membership.updateRoot(rootHash)

      try {
        await membership.connect(accounts[4]).mint(badProof)
      } catch (err) {
        expect(err.message).to.have.string('CodeforDAO Membership: Invalid proof')
      }
    })
  })
})
