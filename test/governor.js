const { expect } = require("chai")
const { ethers } = require("hardhat")
const zeroAddres = ethers.constants.AddressZero;

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

    const governorAddress = await this.membership.governor()
    this.governor = Governor.attach(governorAddress)

    const timelockAddress = await this.governor.timelock()
    this.treasury = Treasury.attach(timelockAddress)
  })

  it("deployment check", async function () {
    expect(await this.governor.name()).to.be.equal(name);
    expect(await this.governor.token()).to.be.equal(this.membership.address);
    expect(await this.governor.name()).to.be.equal(name);
  })

  // describe("#deployment check", function () {
  // })
})
