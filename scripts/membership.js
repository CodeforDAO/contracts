const hre = require("hardhat");

async function main() {
  const contract = await hre.ethers.getContractFactory("Membership");
  const _contract = await contract.deploy();

  await _contract.deployed();

  console.log("Deployed to:", _contract.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
