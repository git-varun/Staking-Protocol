const { ethers } = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();

  // 1. Deploy ProxyAdmin contract
  const ProxyAdmin = await ethers.getContractFactory("ProxyAdmin");
  const proxyAdmin = await ProxyAdmin.deploy();
  await proxyAdmin.waitForDeployment();

  console.log("ProxyAdmin deployed at:", await proxyAdmin.getAddress());
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
