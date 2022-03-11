const hre = require('hardhat');

async function main() {
  const Membership = await hre.ethers.getContractFactory('Membership');
  const Governor = await hre.ethers.getContractFactory('MembershipGovernor');
  const Treasury = await hre.ethers.getContractFactory('Treasury');
  const membership = await Membership.deploy('CodeforDAO', 'CODE', '');

  await membership.deployed();

  console.log('Membership has been deployed to:', membership.address);

  const governorAddress = await membership.governor();
  const deployedGovernor = Governor.attach(governorAddress);
  console.log('- Governor address:', governorAddress);
  const timelockAddress = await deployedGovernor.timelock();
  const deployedTreasury = Treasury.attach(timelockAddress);
  console.log('- Treasury(timelock) address:', timelockAddress);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
