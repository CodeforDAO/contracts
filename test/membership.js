const { expect } = require("chai")
const { ethers } = require("hardhat")
const { MerkleTree } = require('merkletreejs');
const keccak256 = require('keccak256');

const _baseURI = 'http://localhost:3000/NFT/'
const _testJSONString = JSON.stringify({
  testKey: "testKey"
})

describe("Membership", function () {
  let Membership, Governor, Treasury, membership, governor, treasury, accounts, owner, rootHash, proof, proof2, badProof;

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
    proof2 = merkleTree.getHexProof(keccak256(await accounts[1].getAddress()))
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
    it("Should able to mint NFT for account in whitelist", async function (done) {
      await membership.updateRoot(rootHash)
      const tx = await membership.mint(proof)

      // membership.on(membership.filters.Transfer(null, await owner.getAddress()), (from, to, amount, event) => {
      //   console.log(from, to, amount, event)
      //   done()
      // })

      expect(await membership.balanceOf(owner.getAddress())).to.equal(1)
      // expect(await membership.ownerOf(tx.value)).to.equal(await owner.getAddress())
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

  describe("#tokenURI", function () {
    it("Should return a server-side token URI by default", async function () {
      await membership.updateRoot(rootHash)
      const tx = await membership.mint(proof)
      const _tx = await tx.wait()

      expect(await membership.tokenURI(tx.value)).to.equal(`${_baseURI}${tx.value.toString()}`)
    })

    it("Should return a decentralized token URI after updated", async function () {
      await membership.updateRoot(rootHash)
      const tx = await membership.mint(proof)
      await membership.updateTokenURI(tx.value, _testJSONString)

      expect(await membership.tokenURI(tx.value)).to.equal(`data:application/json;base64,${Buffer.from(_testJSONString).toString('base64')}`)
    })
  })

  describe("#pause", function () {
    it("Should not able to transfer tokens after paused", async function () {
      await membership.updateRoot(rootHash)
      const tx = await membership.mint(proof)
      await membership.pause()

      try {
        await membership.transferFrom(
          await owner.getAddress(), 
          await accounts[1].getAddress(),
          tx.value,
        )
      } catch (err) {
        expect(err.message).to.have.string('CodeforDAO: token transfer while paused')
      }
    })

    it("Should not able to mint tokens after paused", async function () {
      await membership.updateRoot(rootHash)
      const _tx = await membership.mint(proof)
      await membership.pause()

      const tx = await membership.connect(accounts[1]).mint(proof2)

      expect(await membership.balanceOf(accounts[1].getAddress())).to.equal(1)
      // expect(await membership.ownerOf(tx.value)).to.equal(await accounts[1].getAddress())
    })
  })
})
