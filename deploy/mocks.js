module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();
  const deployConfig = {
    from: deployer,
    args: [],
    log: true,
  };

  await deploy('CallReceiverMock', deployConfig);
  await deploy('MulticallV1', deployConfig);
};

module.exports.tags = ['Mocks'];
