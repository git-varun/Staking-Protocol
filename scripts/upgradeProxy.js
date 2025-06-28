// scripts/upgradeProxy.js
const { ethers } = require("hardhat");

async function main() {
  // Replace these with your actual deployed addresses:
  const proxyAddress = "0x1234567890abcdef1234567890abcdef12345678";      // <-- real proxy address
  const newLogicAddress = "0xabcdefabcdefabcdefabcdefabcdefabcdefabcd";    // <-- real new logic address
  const proxyAdminAddress = "0x9876543210abcdef9876543210abcdef98765432"; // <-- real proxy admin address

  const proxyAdmin = await ethers.getContractAt("ProxyAdmin", proxyAdminAddress);
  const tx = await proxyAdmin.upgrade(proxyAddress, newLogicAddress);
  await tx.wait();

  console.log("Proxy upgraded successfully.");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
