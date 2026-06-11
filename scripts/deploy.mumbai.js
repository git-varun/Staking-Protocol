// Deployment script for Polygon Mumbai Testnet
const { ethers } = require('hardhat');

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log(`\n🚀 Deploying to Mumbai Testnet`);
  console.log(`Account: ${deployer.address}`);

  // 1. Deploy Implementation
  console.log('\n1️⃣  Deploying StakingProtocol...');
  const StakingProtocol = await ethers.getContractFactory('StakingProtocol');
  const stakingImpl = await StakingProtocol.deploy();
  await stakingImpl.waitForDeployment();
  const implAddress = await stakingImpl.getAddress();
  console.log(`   ✅ ${implAddress}`);

  // 2. Deploy ProxyAdmin
  console.log('\n2️⃣  Deploying ProxyAdmin...');
  const ProxyAdmin = await ethers.getContractFactory('ProxyAdmin');
  const proxyAdmin = await ProxyAdmin.deploy();
  await proxyAdmin.waitForDeployment();
  const adminAddress = await proxyAdmin.getAddress();
  console.log(`   ✅ ${adminAddress}`);

  // 3. Deploy Proxy
  console.log('\n3️⃣  Deploying StakingProxy...');
  const Proxy = await ethers.getContractFactory('StakingProxy');
  const proxy = await Proxy.deploy(implAddress);
  await proxy.waitForDeployment();
  const proxyAddress = await proxy.getAddress();
  console.log(`   ✅ ${proxyAddress}`);

  // 4. Change Admin
  console.log('\n4️⃣  Configuring proxy admin...');
  await proxy.changeAdmin(adminAddress);
  console.log(`   ✅ Done`);

  // 5. Initialize
  console.log('\n5️⃣  Initializing protocol...');
  const stakingAsProxy = await ethers.getContractAt('StakingProtocol', proxyAddress);
  await stakingAsProxy.initialize(deployer.address, 86400);
  console.log(`   ✅ Done`);

  console.log('\n' + '='.repeat(60));
  console.log('📋 MUMBAI DEPLOYMENT COMPLETE');
  console.log('='.repeat(60));
  console.log(`Implementation: https://mumbai.polygonscan.com/address/${implAddress}`);
  console.log(`Proxy:          https://mumbai.polygonscan.com/address/${proxyAddress}`);
  console.log(`ProxyAdmin:     https://mumbai.polygonscan.com/address/${adminAddress}`);
  console.log('='.repeat(60));
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
