const { expect } = require("chai")
const { ethers } = require("hardhat")
const { MerkleTree } = require('merkletreejs');
const keccak256 = require('keccak256');

const _baseURI = 'http://localhost:3000/NFT/'

describe("Governor", function () {
  const name = 'MembershipGovernor'

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

  it("deployment check", async function () {
    expect(await this.governor.name()).to.be.equal(name);
    expect(await this.governor.token()).to.be.equal(this.membership.address);
    expect(await this.governor.votingDelay()).to.be.equal(6575);
    expect(await this.governor.votingPeriod()).to.be.equal(46027);
    expect(await this.governor.proposalThreshold()).to.be.equal(0);
    expect(await this.governor.quorum(0)).to.be.equal(0);
  })
})
