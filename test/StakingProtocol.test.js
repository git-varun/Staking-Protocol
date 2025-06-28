// test/StakingProtocol.test.js
const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("StakingProtocol", function () {
  let deployer, user, StakingLogic, staking, proxy, proxyAsStaking;

  beforeEach(async () => {
    [deployer, user] = await ethers.getSigners();

    // Deploy logic contract
    StakingLogic = await ethers.getContractFactory("StakingProtocol");
    staking = await StakingLogic.deploy();
    await staking.waitForDeployment();

    // Deploy proxy
    const Proxy = await ethers.getContractFactory("StakingProxy");
    proxy = await Proxy.deploy(await staking.getAddress());
    await proxy.waitForDeployment();

    // Re-bind proxy to logic ABI
    proxyAsStaking = new ethers.Contract(await proxy.getAddress(), StakingLogic.interface, deployer);

    // Initialize
    await proxyAsStaking.initialize(deployer.address, 86400); // 1-day cliff
  });

  it("should initialize the contract", async () => {
    expect(await proxyAsStaking.owner()).to.equal(deployer.address);
    expect(await proxyAsStaking.cliff()).to.equal(86400);
  });

  it("should create a pool", async () => {
    const token = await ethers.deployContract("SampleERC20");
    const reward = await ethers.deployContract("SampleERC20");

    await proxyAsStaking.createPool(await token.getAddress(), await reward.getAddress(), 100);

    const pool = await proxyAsStaking.fetchPoolInfo(1);
    expect(pool.stakingToken).to.equal(await token.getAddress());
    expect(pool.rewardToken).to.equal(await reward.getAddress());
    expect(pool.yieldPerSecond).to.equal(100);
  });

  it("should not allow non-owner to create a pool", async () => {
    const token = await ethers.deployContract("SampleERC20");
    const reward = await ethers.deployContract("SampleERC20");
    await expect(
      proxyAsStaking.connect(user).createPool(await token.getAddress(), await reward.getAddress(), 100)
    ).to.be.reverted;
  });

  it("should allow staking and update balances", async () => {
    const token = await ethers.deployContract("SampleERC20");
    const reward = await ethers.deployContract("SampleERC20");
    await proxyAsStaking.createPool(await token.getAddress(), await reward.getAddress(), 100);

    // Get the latest poolId
    const poolId = await proxyAsStaking.poolCount();

    // Mint and approve tokens
    await token.mint(user.address, 1000);
    await token.connect(user).approve(await proxy.getAddress(), 500);

    // Stake tokens in the correct pool
    await proxyAsStaking.connect(user).stakeToken(poolId, 500);

    const stakeInfo = await proxyAsStaking.stakeInfo(user.address, poolId);
    expect(stakeInfo.stakeAmount).to.equal(500);
  });

  it("should not allow staking before pool is created", async () => {
    const token = await ethers.deployContract("SampleERC20");
    await token.mint(user.address, 1000);
    await token.connect(user).approve(await proxy.getAddress(), 500); // <-- FIXED LINE
    await expect(
      proxyAsStaking.connect(user).stakeToken(1, 500)
    ).to.be.reverted;
  });

  it("should allow owner to change cliff", async () => {
    await proxyAsStaking.setCliff(172800); // 2 days
    expect(await proxyAsStaking.cliff()).to.equal(172800);
  });

  it("should not allow non-owner to change cliff", async () => {
    await expect(
      proxyAsStaking.connect(user).setCliff(172800)
    ).to.be.reverted;
  });
});