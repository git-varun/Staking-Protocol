// Deployment script for Sepolia testnet
const { ethers } = require('hardhat');

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log(`\n🚀 Deploying contracts with account: ${deployer.address}`);
  console.log(`Network: sepolia`);

  // 1. Deploy Implementation (StakingProtocol)
  console.log('\n1️⃣  Deploying StakingProtocol implementation...');
  const StakingProtocol = await ethers.getContractFactory('StakingProtocol');
  const stakingImpl = await StakingProtocol.deploy();
  await stakingImpl.waitForDeployment();
  const implAddress = await stakingImpl.getAddress();
  console.log(`   ✅ Implementation deployed: ${implAddress}`);

  // 2. Deploy ProxyAdmin
  console.log('\n2️⃣  Deploying ProxyAdmin...');
  const ProxyAdmin = await ethers.getContractFactory('ProxyAdmin');
  const proxyAdmin = await ProxyAdmin.deploy();
  await proxyAdmin.waitForDeployment();
  const adminAddress = await proxyAdmin.getAddress();
  console.log(`   ✅ ProxyAdmin deployed: ${adminAddress}`);

  // 3. Deploy Proxy
  console.log('\n3️⃣  Deploying StakingProxy...');
  const Proxy = await ethers.getContractFactory('StakingProxy');
  const proxy = await Proxy.deploy(implAddress);
  await proxy.waitForDeployment();
  const proxyAddress = await proxy.getAddress();
  console.log(`   ✅ Proxy deployed: ${proxyAddress}`);

  // 4. Change Proxy Admin
  console.log('\n4️⃣  Transferring proxy admin to ProxyAdmin contract...');
  await proxy.changeAdmin(adminAddress);
  console.log(`   ✅ Proxy admin transferred`);

  // 5. Initialize Protocol
  console.log('\n5️⃣  Initializing StakingProtocol...');
  const stakingAsProxy = await ethers.getContractAt('StakingProtocol', proxyAddress);
  const cliffDuration = 86400; // 1 day
  await stakingAsProxy.initialize(deployer.address, cliffDuration);
  console.log(`   ✅ Initialized with cliff: ${cliffDuration}s`);

  // 6. Verify implementation
  console.log('\n6️⃣  Verifying implementation...');
  const owner = await stakingAsProxy.owner();
  const cliff = await stakingAsProxy.cliff();
  console.log(`   Owner: ${owner}`);
  console.log(`   Cliff: ${cliff}`);

  // Summary
  console.log('\n' + '='.repeat(60));
  console.log('📋 DEPLOYMENT SUMMARY (Sepolia)');
  console.log('='.repeat(60));
  console.log(`StakingProtocol (impl): ${implAddress}`);
  console.log(`StakingProxy:           ${proxyAddress}`);
  console.log(`ProxyAdmin:             ${adminAddress}`);
  console.log('='.repeat(60));
  console.log('\n📝 Save these addresses for verification and future upgrades!\n');

  // Auto-verify if ETHERSCAN_API_KEY is set
  if (process.env.ETHERSCAN_API_KEY) {
    console.log('\n⏳ Waiting 30s before verification...');
    await new Promise(resolve => setTimeout(resolve, 30000));
    
    try {
      console.log('\n🔍 Verifying contracts on Etherscan...');
      await hre.run('verify:verify', {
        address: implAddress,
        constructorArguments: [],
      });
      console.log(`✅ Implementation verified: https://sepolia.etherscan.io/address/${implAddress}`);
    } catch (err) {
      console.log(`⚠️  Verification failed (contract may already be verified): ${err.message}`);
    }
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
