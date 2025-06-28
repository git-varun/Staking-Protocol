const { ethers } = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();
  // Replace these with actual addresses:
  const proxyAddress = "0x1234567890abcdef1234567890abcdef12345678";
  const newLogicAddress = "0xabcdefabcdefabcdefabcdefabcdefabcdefabcd";
  const proxyAdminAddress = "0x9876543210abcdef9876543210abcdef98765432";

  const admin = await ethers.getContractAt("ProxyAdmin", proxyAdminAddress);
  const tx = await admin.upgrade(proxyAddress, newLogicAddress);
  await tx.wait();

  console.log("Proxy upgraded to new logic:", newLogicAddress);
}

main().catch(console.error);
