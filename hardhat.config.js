require("dotenv").config();
require("@nomicfoundation/hardhat-toolbox");
require("@nomicfoundation/hardhat-verify");
require("solidity-coverage");

const privateKey = process.env.PRIVATE_KEY;
if (!privateKey || privateKey.length !== 64) {
  throw new Error("❌ Invalid PRIVATE_KEY in .env (must be 64 hex chars without 0x)");
}

module.exports = {
  solidity: {
    compilers: [
      {
        version: "0.8.12",
      },
      {
        version: "0.8.20",
      },
    ],
  },
  networks: {
    hardhat: {
      chainId: 1337,
    },
    sepolia: {
      url: process.env.SEPOLIA_RPC_URL || "",
      accounts: [privateKey],
      chainId: 11155111,
    },
    mainnet: {
      url: process.env.MAINNET_RPC_URL || "",
      accounts: [privateKey],
      chainId: 1,
    },
    polygon: {
      url: process.env.POLYGON_RPC_URL || "",
      accounts: [privateKey],
      chainId: 137,
    },
    polygonMumbai: {
      url: process.env.POLYGON_MUMBAI_RPC_URL || "",
      accounts: [privateKey],
      chainId: 80001,
    },
  },
  etherscan: {
    apiKey: {
      mainnet: process.env.ETHERSCAN_API_KEY || "",
      sepolia: process.env.ETHERSCAN_API_KEY || "",
      polygon: process.env.POLYGONSCAN_API_KEY || "",
      polygonMumbai: process.env.POLYGONSCAN_API_KEY || "",
    },
  },
  gasReporter: {
    enabled: process.env.REPORT_GAS === "true",
    currency: "USD",
    coinmarketcap: process.env.COINMARKETCAP_API_KEY || "",
  },
};
