module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();
  const deployConfig = {
    from: deployer,
    args: [],
    log: true,
  };

  await deploy('CallReceiverMock', deployConfig);
  await deploy('Multicall', deployConfig);
};

module.exports.tags = ['Mocks'];
