// Deployment script for Ethereum Mainnet (PRODUCTION)
// ⚠️  WARNING: This deploys to mainnet. Use with extreme caution!
const { ethers } = require('hardhat');

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log(`\n🚀 MAINNET DEPLOYMENT - Deploying contracts with account: ${deployer.address}`);
  console.log(`Network: mainnet`);
  console.log(`\n⚠️  WARNING: This is a PRODUCTION deployment to Ethereum Mainnet!\n`);

  // 1. Deploy Implementation
  console.log('1️⃣  Deploying StakingProtocol implementation...');
  const StakingProtocol = await ethers.getContractFactory('StakingProtocol');
  const stakingImpl = await StakingProtocol.deploy();
  await stakingImpl.waitForDeployment();
  const implAddress = await stakingImpl.getAddress();
  console.log(`   ✅ Implementation: ${implAddress}`);

  // 2. Deploy ProxyAdmin
  console.log('\n2️⃣  Deploying ProxyAdmin...');
  const ProxyAdmin = await ethers.getContractFactory('ProxyAdmin');
  const proxyAdmin = await ProxyAdmin.deploy();
  await proxyAdmin.waitForDeployment();
  const adminAddress = await proxyAdmin.getAddress();
  console.log(`   ✅ ProxyAdmin: ${adminAddress}`);

  // 3. Deploy Proxy
  console.log('\n3️⃣  Deploying StakingProxy...');
  const Proxy = await ethers.getContractFactory('StakingProxy');
  const proxy = await Proxy.deploy(implAddress);
  await proxy.waitForDeployment();
  const proxyAddress = await proxy.getAddress();
  console.log(`   ✅ Proxy: ${proxyAddress}`);

  // 4. Transfer Proxy Admin
  console.log('\n4️⃣  Transferring proxy admin...');
  await proxy.changeAdmin(adminAddress);
  console.log(`   ✅ Proxy admin transferred to ProxyAdmin contract`);

  // 5. Initialize
  console.log('\n5️⃣  Initializing StakingProtocol...');
  const stakingAsProxy = await ethers.getContractAt('StakingProtocol', proxyAddress);
  const cliffDuration = 2592000; // 30 days
  await stakingAsProxy.initialize(deployer.address, cliffDuration);
  console.log(`   ✅ Initialized with 30-day cliff`);

  // Summary
  console.log('\n' + '='.repeat(70));
  console.log('✅ MAINNET DEPLOYMENT COMPLETE');
  console.log('='.repeat(70));
  console.log(`StakingProtocol (impl): https://etherscan.io/address/${implAddress}`);
  console.log(`StakingProxy:           https://etherscan.io/address/${proxyAddress}`);
  console.log(`ProxyAdmin:             https://etherscan.io/address/${adminAddress}`);
  console.log('='.repeat(70));
  console.log(`\n📝 SAVE THESE ADDRESSES!\n`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
