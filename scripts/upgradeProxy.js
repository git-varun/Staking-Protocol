// scripts/upgradeProxy.js
const { ethers } = require("hardhat");

async function main() {
  const proxyAddress = "0xProxyAddressHere";
  const newLogicAddress = "0xNewLogicHere";
  const proxyAdminAddress = "0xProxyAdminHere";

  const proxyAdmin = await ethers.getContractAt("ProxyAdmin", proxyAdminAddress);
  const tx = await proxyAdmin.upgrade(proxyAddress, newLogicAddress);
  await tx.wait();

  console.log("Proxy upgraded successfully.");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
