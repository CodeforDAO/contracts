const { expect } = require("chai")
const { ethers } = require("hardhat")
const { MerkleTree } = require('merkletreejs');
const keccak256 = require('keccak256');

const _baseURI = 'http://localhost:3000/NFT/'
const _Votes = {
  Against: 0,
  For: 1,
  Abstain: 2,
}

describe("Governor", function () {
  const name = 'MembershipGovernor'

  before(async function () {
    this.accounts = await ethers.getSigners()
    this.owner = this.accounts[0]
    this.ownerAddress = await this.owner.getAddress()

    // Create a test merkle tree
    const voters = this.accounts.filter((_, idx) => idx < 4)
    const leafNodes = (await Promise.all(voters
      .map(account => account.getAddress()))).map(adr => keccak256(adr));
    const merkleTree = new MerkleTree(leafNodes, keccak256, { 
      sortPairs: true, 
    });

    this.rootHash = merkleTree.getHexRoot()
    this.proofs = (await Promise.all(voters
      .map(account => account.getAddress()))).map(addr => merkleTree.getHexProof(keccak256(addr)))
    this.voters = voters
    this.votersAddresses = await Promise.all(voters.map(v => v.getAddress()))
  })

  beforeEach(async function () {
    // Deploy Membership contract
    const Membership = await ethers.getContractFactory("Membership")
    const Governor = await ethers.getContractFactory("MembershipGovernor")
    const Treasury = await ethers.getContractFactory("Treasury")
    const CallReceiverMock = await ethers.getContractFactory("CallReceiverMock")

    this.membership = await Membership.deploy(
      'CodeforDAO',
      'CODE',
      _baseURI,
    )
    this.receiver = await CallReceiverMock.deploy()

    await this.membership.deployed()
    await this.receiver.deployed()

    this.governor = Governor.attach(await this.membership.governor())
    this.treasury = Treasury.attach(await this.governor.timelock())

    await this.membership.updateRoot(this.rootHash)

    // Do NOT use `this.voters.forEach` to avoid a block number change
    await Promise.all(
      this.voters.map((voter, idx) => {
        return Promise.all([
          this.membership.connect(voter).mint(this.proofs[idx]),
          this.membership.connect(voter).delegate(this.votersAddresses[idx]),
        ])
      })
    )

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
    ]

    this.shortProposal = [
      this.proposal[0],
      this.proposal[1],
      this.proposal[2],
      keccak256(this.proposal.slice(-1).find(Boolean))
    ]

    this.proposalId = await this.governor.hashProposal(
      ...this.shortProposal
    )
  })

  it("deployment check", async function () {
    expect(await this.governor.name()).to.be.equal(name);
    expect(await this.governor.token()).to.be.equal(this.membership.address);
    expect(await this.governor.votingDelay()).to.be.equal(0);
    expect(await this.governor.votingPeriod()).to.be.equal(46027);
    expect(await this.governor.proposalThreshold()).to.be.equal(1);
    expect(await this.governor.quorum(0)).to.be.equal(0);

    // Can use `this.voters.forEach` to expect test cases
    this.voters.forEach(async (adr, idx) => {
      expect(await this.membership.balanceOf(this.votersAddresses[idx])).to.be.equal(1);
      expect(await this.membership.getVotes(this.votersAddresses[idx])).to.be.equal(1);
    })
  })

  describe("#propose", function () {
    it("Should able to make a valid propose", async function () {
      await expect(this.governor.connect(this.owner).functions[
        'propose(address[],uint256[],bytes[],string)'
      ](
        ...this.proposal
      )).to.emit(this.governor, 'ProposalCreated')
    })

    // this.accounts[4] is not a voter
    it("Should not able to make a valid propose if user do not hold a NFT membership", async function () {
      await expect(this.governor.connect(this.accounts[4]).functions[
        'propose(address[],uint256[],bytes[],string)'
      ](
        ...this.proposal
      )).to.be.revertedWith('GovernorCompatibilityBravo: proposer votes below proposal threshold')
    })
  })

  describe("#vote", function () {
    it("Should able to cast votes on a valid proposal", async function () {
      await expect(this.governor.connect(this.owner).functions[
        'propose(address[],uint256[],bytes[],string)'
      ](
        ...this.proposal
      )).to.emit(this.governor, 'ProposalCreated')

      await expect(
        this.governor.connect(this.voters[1]).castVote(this.proposalId, _Votes.For)
      ).to.emit(this.governor, 'VoteCast')
        .withArgs(await this.voters[1].getAddress(), this.proposalId, _Votes.For, 1, '')

      expect(await this.governor.connect(this.voters[1]).hasVoted(this.proposalId, await this.voters[1].getAddress())).to.be.equal(true)

      await expect(
        this.governor.connect(this.voters[2]).castVoteWithReason(this.proposalId, _Votes.Against, "I don't like this proposal")
      ).to.emit(this.governor, 'VoteCast')
        .withArgs(await this.voters[2].getAddress(), this.proposalId, _Votes.Against, 1, "I don't like this proposal")
    })

    // this.accounts[4] is not a voter
    it("Should not able to cast vote if user do not hold a NFT membership", async function () {
      await expect(this.governor.connect(this.owner).functions[
        'propose(address[],uint256[],bytes[],string)'
      ](
        ...this.proposal
      )).to.emit(this.governor, 'ProposalCreated')

      await expect(
        this.governor.connect(this.accounts[4]).castVote(this.proposalId, _Votes.For)
      ).to.be.revertedWith('MembershipGovernor: voter votes below proposal threshold')
    })
  })
})
