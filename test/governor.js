const { expect } = require("chai")
const { ethers } = require("hardhat")

const _baseURI = 'http://localhost:3000/NFT/'

describe("Governor", function () {
  const name = 'MembershipGovernor'

  before(async function () {
    const accounts = await ethers.getSigners()

    this.owner = accounts[0]
    this.proposer = accounts[1]
    this.voter1 = accounts[2]
    this.voter2 = accounts[3]
    this.voter3 = accounts[4]
    this.voter4 = accounts[5]
  })

  // Deploy Membership contract
  beforeEach(async function () {
    const Membership = await ethers.getContractFactory("Membership")
    const Governor = await ethers.getContractFactory("MembershipGovernor")
    const Treasury = await ethers.getContractFactory("Treasury")

    this.membership = await Membership.deploy(
      'CodeforDAO',
      'CODE',
      _baseURI,
    )

    await this.membership.deployed()

    const governorAddress = await this.membership.governor()
    this.governor = Governor.attach(governorAddress)

    const timelockAddress = await this.governor.timelock()
    this.treasury = Treasury.attach(timelockAddress)
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
