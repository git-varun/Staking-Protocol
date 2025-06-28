const { ethers } = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();

  const Factory = await ethers.getContractFactory("RewardStrategyFactory");
  const factory = await Factory.deploy();
  await factory.waitForDeployment();

  console.log("RewardStrategyFactory deployed at:", await factory.getAddress());

  // Example: deploy Linear strategy
  const tx = await factory.deployLinearStrategy(1, ethers.parseUnits("1", "wei")); // 1 wei/sec
  const receipt = await tx.wait();

  const event = receipt.logs.find(log => log.fragment?.name === "StrategyDeployed");
  const strategyAddr = event?.args?.strategy;
  console.log("Strategy for pool 1 deployed at:", strategyAddr);
}

main().catch(console.error);
