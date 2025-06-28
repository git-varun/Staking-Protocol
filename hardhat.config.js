require("dotenv").config();
require("@nomicfoundation/hardhat-toolbox");
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
    hardhat: {},
    polygon: {
      url: "process.env.POLYGON_RPC_URL",
      accounts: [privateKey],
    },
  },
};
