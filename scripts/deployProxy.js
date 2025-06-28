const { ethers } = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log(`Deploying with: ${deployer.address}`);

  // 1. Deploy Logic Contract (StakingProtocolV1)
  const StakingProtocol = await ethers.getContractFactory("StakingProtocol");
  const stakingLogic = await StakingProtocol.deploy();
  await stakingLogic.deployed();
  console.log(`Staking Logic deployed at: ${stakingLogic.address}`);

  // 2. Deploy Proxy Contract with logic address
  const Proxy = await ethers.getContractFactory("StakingProxy");
  const proxy = await Proxy.deploy(stakingLogic.address);
  await proxy.deployed();
  console.log(`Proxy deployed at: ${proxy.address}`);

  // 3. Initialize Logic via Proxy
  const stakingProxy = await ethers.getContractAt("StakingProtocol", proxy.address);
  const tx = await stakingProxy.initialize(deployer.address, 3 * 86400); // example: 3 days cliff
  await tx.wait();
  console.log("Initialized Proxy logic");

  // ✅ Optional: Save in `.env` or frontend artifact
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
