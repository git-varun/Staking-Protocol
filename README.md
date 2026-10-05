# Staking Protocol

An upgradeable staking contract in Solidity (Foundry). Users stake ERC-20 tokens or ERC-721 NFTs into owner-created pools and earn rewards. Each pool can use a pluggable reward strategy. The repo includes a unit, fuzz and stateful invariant test suite, and the bugs it found are in [`FINDINGS.md`](FINDINGS.md).

## What it does

- **Pools.** The owner creates pools, each with a staking token, a reward token and a yield per second. Pools can be paused or deactivated, and the whole protocol can be paused.
- **ERC-20 staking.** `stakeToken` deposits tokens. `claimRewards(poolId, unStake)` pays out rewards and optionally withdraws the stake. Rewards are only claimable after a global **cliff** period. `emergencyWithdraw` returns the stake with no rewards.
- **NFT staking.** `stakeNft` and `unstakeNft` lock ERC-721 tokens in pools that are mapped to an NFT contract. They earn time-based rewards after the cliff.
- **Reward strategies.** A pool can point to an `IRewardStrategy` that computes rewards. The `RewardStrategyFactory` deploys three kinds:
  | Strategy | Reward formula |
  |----------|----------------|
  | `LinearRewardStrategy` | `staked * elapsed * yieldPerSecond / 1 year` |
  | `FixedPerBlockStrategy` | `blocksElapsed * fixedReward` |
  | `NftBoostedStrategy` | linear reward scaled by `1 + nftCount * boostMultiplier` |
- **Upgradeability.** `StakingProxy` is an EIP-1967 proxy. `ProxyAdmin` manages upgrades. `StakingProtocol` has a storage gap and an `initialize` function.

## Layout

```
src/
  core/StakingProtocol.sol        main staking logic
  interfaces/                     IStakingProtocol, IRewardStrategy
  libraries/StakingConstants.sol  revert messages
  proxy/                          StakingProxy (EIP-1967), ProxyAdmin
  strategies/                     Linear, FixedPerBlock, NftBoosted
  RewardStrategyFactory.sol       deploys strategies per pool
test/
  unit/ fuzz/ invariant/          test suites (see below)
FINDINGS.md                       bugs found by fuzzing, plus mutation checks
docs/                             design spec
```

## Build and test

Requires [Foundry](https://book.getfoundry.sh/). OpenZeppelin is a git submodule.

```sh
git submodule update --init --recursive
forge build
forge test                 # unit + fuzz + invariant
forge test --gas-report
```

Fuzz runs, invariant runs and depth are set in `foundry.toml`.

## Test suite

- **Unit** (`test/unit`): the happy paths and the revert cases.
- **Fuzz** (`test/fuzz`): strategy math with bounded inputs.
- **Invariant** (`test/invariant`): a handler drives stake, claim, exit, time warps, admin actions and outsider calls. The suite checks these properties:

| ID | Property |
|----|----------|
| INV-1 | `totalStaked` equals the sum of all actor stakes, per pool |
| INV-2 | staking-token balance held >= `totalStaked` (solvency) |
| INV-3 | tokens received minus tokens returned == `totalStaked` (ghost accounting) |
| INV-4 | rewards paid per actor <= an independent model maximum (Linear only) |
| INV-5 | `owner` changes only through an owner-authorized path |
| INV-6 | nothing feeding reward-rate math is changeable by a non-owner |
| INV-7 | no reward leaves before the cliff has elapsed |
| INV-8 | any actor with a stake can always exit |
| INV-9 | no handler call reverts with a Panic |

Each invariant was also mutation-checked: reintroduce the bug and confirm that the matching invariant fails. See `FINDINGS.md` for the results.

## Scope and caveats

The invariant suite covers the ERC-20 path, the three strategies through the factory, admin functions and upgrade safety. The NFT path and fee-on-transfer tokens are not covered. This is a learning and practice project and **has not been audited**. Do not use it with real funds.
