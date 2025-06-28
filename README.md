# Staking-Protocol

A flexible and secure staking smart contract system supporting both ERC20 and ERC721 tokens, with customizable reward strategies and safe transfer mechanisms.

## Features

- **Supports ERC20 and ERC721 staking:** Users can stake fungible or non-fungible tokens.
- **Customizable reward strategies:** Easily implement and plug in new reward logic.
- **Safe transfer:** Assets are transferred securely during staking and withdrawal.
- **Upgradeable architecture:** Proxy design allows for contract upgrades.
- **Comprehensive testing:** Includes JavaScript/Hardhat-based test suite.
- **Well-documented:** Protocol specification PDF included.

## Structure

```
contracts/
  RewardStrategyFactory.sol
  core/
  interfaces/
  proxy/
  strategies/
  test/
test/
  StakingProtocol.test.js
scripts/
hardhat.config.js
package.json
README.md
Staking Protocol.pdf
```

## Getting Started

1. **Install dependencies:**
   ```bash
   yarn install
   # or
   npm install
   ```

2. **Compile contracts:**
   ```bash
   npx hardhat compile
   ```

3. **Run tests:**
   ```bash
   npx hardhat test
   ```

4. **Deploy contracts:**
   Edit deployment scripts in the `scripts/` directory and run with Hardhat.

## Components

- **RewardStrategyFactory.sol:** Factory for creating/managing reward strategies.
- **core/:** Core protocol logic and state management.
- **interfaces/:** Interface contracts for staking and token standards.
- **proxy/:** Upgradeability/proxy contracts.
- **strategies/:** Implementations of various reward strategies.
- **test/:** Test contracts and JavaScript tests.
- **scripts/:** Deployment and utility scripts.

## Documentation

- See `Staking Protocol.pdf` for the protocol specification and detailed explanation.
- The `report/` directory may contain audit or coverage reports.

## License

See [LICENSE](./LICENSE).

---

**Note:** For a full directory listing, visit the [repository contents page](https://github.com/git-varun/Staking-Protocol/contents/).