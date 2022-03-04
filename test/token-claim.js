const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("TokenClaim", function () {
  it("Should return hardcoded test wallet address", async function () {
    const Token = await ethers.getContractFactory("TokenClaim");
    const token = await Token.deploy();
    await token.deployed();

    expect(await token.TEST_WALLET()).to.equal("0xb0daCC029B2722055B71c6839Fb56d1EEE4Db2F2");
  });
});
