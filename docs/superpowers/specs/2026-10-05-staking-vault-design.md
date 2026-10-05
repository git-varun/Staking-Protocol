# Staking Vault Protocol — Design (V1)

Date: 2026-10-05
Status: Draft for review

## 1. Summary

Replace the current monolithic `StakingProtocol` (raw balances, pluggable reward strategies, hand-rolled proxy) with a modular, production-standard system:

- **StakingVault**: an ERC-4626 vault that holds *only* user principal and streams rewards from a separately funded budget.
- **StakingRegistry**: factory and directory for vaults, token policy, roles.
- **StakingRouter** and **StakingLens**: periphery for UX (permit, multicall, reads).

V1 delivers staking with vaults only. NFT boost, auto-compounding and vesting are later versions; V1 reserves extension points but builds none of them.

## 2. Goals and non-goals

### Goals
- Principal can never be spent on rewards (fixes solvency finding INV-2).
- No user-controllable or open reward inputs (fixes unauthenticated boost, block-number reward, stray strategy bugs).
- A trust model where no role can move, redirect or freeze user principal.
- Standard interfaces (ERC-4626) so wallets, explorers and aggregators understand positions.
- Small, auditable core with strong test coverage (unit, fuzz, invariant, fork, mutation).

### Non-goals (V1)
- NFT boost, auto-compounding, reward vesting (later versions).
- Multiple reward tokens per vault, protocol fees, per-deposit lock lots.
- USD APR or any price oracle.
- Transferable shares.
- Upgradeable vaults (see 5.1; beacon is the fallback path).

## 3. Understanding and assumptions

Stated by the user: strategies are the main source of bugs; use a real vault to hold tokens; keep it useful without being complex; production-level standards, with a registry and helper contracts; immutable vaults first, beacon only if issues are found; NFT boost, auto-compounding and vesting are later versions.

Assumptions (correct if wrong):
- Learning/portfolio project; no real funds until audited and rehearsed on a testnet.
- EVM target; mainnet-style tokens (USDC, USDT, DAI) must work.
- Solidity ^0.8.20, Foundry, OpenZeppelin v5.

## 4. Architecture

```
                    Timelock (OZ) ◄── Multisig (admin)
                         │ owns
          ┌──────────────┴───────────────┐
          ▼                              ▼
   StakingRegistry                  Guardian (pause deposits only)
   (factory + directory)
          │ deploys EIP-1167 clone (CREATE2) per vault
          ▼
   ┌───────────────────────────────┐
   │ StakingVault (ERC-4626)       │
   │  principal only, shares=receipt│
   │  reward stream (internal)     │◄── fundRewards() by reward manager
   └───────────────────────────────┘
          ▲                    ▲
    StakingRouter         StakingLens
  (permit + multicall)    (read-only)
```

| Contract | Responsibility | Holds funds |
|---|---|---|
| `StakingVault` | Deposit/withdraw, shares, reward stream, lockup, claim, lifecycle states | Yes (principal + funded rewards) |
| `StakingRegistry` | Create vaults, directory, token policy, implementation versioning, trusted router, roles | No |
| `StakingRouter` | `depositWithPermit`, `multicall`, `claimAll`, `exitAll` | No (transient only) |
| `StakingLens` | Read-only aggregation for UIs | No |
| `TimelockController` (OZ) | Delayed admin actions | No |

## 5. Design decisions

### 5.1 Immutable vaults (beacon is the fallback)
Vaults are EIP-1167 clones of one audited implementation: immutable once deployed. Deployment is isolated in `_deploy(impl, salt, initData)` so a move to `BeaconProxy` later changes only that function. The vault uses an initializer (not a constructor) so it works under both. Move to a beacon only if a bug cannot be handled by shutdown plus migration (for example, migration is too disruptive for locked users).

Migration path: register a new implementation (affects only new vaults), create new vaults, users exit and redeposit; the router bundles that into one call.

### 5.2 Internal principal accounting
`totalAssets()` returns an internal `totalStaked` counter, not `balanceOf`.
- Direct donations cannot change share value, which removes the ERC-4626 inflation attack.
- Principal and rewards stay separate even when `rewardToken == asset`.
- In V1 shares are effectively 1:1 with deposits. Yield is paid as rewards, not share-price growth. Price growth is introduced by auto-compounding later without an interface change.

### 5.3 Deposit on behalf
`deposit(assets, receiver)` and `mint` require `msg.sender == receiver` or `msg.sender == registry.trustedRouter()`. This stops a third party from extending someone's lock or bypassing a lock by depositing through a friend.

### 5.4 Non-transferable shares
Shares are visible in wallets but cannot be moved (`_update` reverts unless mint or burn). This keeps reward accounting and locks per-address. Transferability is a later change with a settle-on-transfer hook.

## 6. StakingVault

### 6.1 State
- Immutable-after-init: `asset`, `rewardToken`, `lockDuration`, `registry`.
- `totalStaked`, `lockedUntil[user]`.
- Rewards: `rewardRate`, `periodFinish`, `lastUpdateTime`, `rewardsDuration`, `rewardPerShareStored`, `userRewardPerSharePaid[user]`, `earnedStored[user]`, `rewardsReserved` (funded minus claimed).
- `state`: `Active`, `DepositsPaused`, `Shutdown`.
- `rewardManager`.

### 6.2 Reward maths
- `rewardPerShare = stored + rewardRate * (min(now, periodFinish) - lastUpdateTime) * 1e18 / totalSupply`.
- `earned(user) = shares * (rewardPerShare - paid[user]) / 1e18 + earnedStored[user]`.
- All updates run through a single `updateReward(user)` modifier on deposit, withdraw, claim and fund.
- Rounding is always down (in the vault's favour); dust stays in the vault.
- **Empty vault:** if `totalSupply == 0`, the stream pauses by shifting `periodFinish` forward by the elapsed time, so rewards are never lost.
- **Funding:** `fundRewards(amount)` (reward manager) pulls tokens (balance-delta measured), sets `rewardRate = (amount + leftover) / duration`, resets `periodFinish`. Requires the reward balance (excluding `totalStaked` when `rewardToken == asset`) to cover `rewardsReserved`.
- Duration changeable only when no period is running; bounded by min and max set in the registry.
- Funded rewards cannot be pulled back by anyone.

### 6.3 Functions
- ERC-4626: `deposit`, `mint`, `withdraw`, `redeem`, `maxDeposit` (0 unless Active), `maxWithdraw` and `maxRedeem` (0 while locked unless Shutdown), previews.
- `claim(receiver)`: pays earned rewards to `receiver` (supports blacklisted addresses).
- `exit()`: withdraw all and claim in one call.
- `fundRewards(amount)`, `setRewardsDuration(d)`, `setRewardManager(a)` (admin).
- `pauseDeposits()` / `unpauseDeposits()` (guardian), `shutdown()` (admin, irreversible).
- `sweep(token, to)`: recovers stray tokens only; can never touch `totalStaked` or `rewardsReserved`.

### 6.4 Lockup
If `lockDuration > 0`, each deposit sets `lockedUntil[receiver] = now + lockDuration`. Withdraw requires `now >= lockedUntil` or `state == Shutdown`. Pausing never blocks withdrawals.

### 6.5 Lifecycle
`Active` → `DepositsPaused` (guardian, reversible) → `Shutdown` (admin, final: deposits off, locks lifted, claims still work).

### 6.6 Safety
Reentrancy guard, checks-effects-interactions, `SafeERC20`, balance-delta checks on all inbound transfers, events for every state and parameter change, custom errors.

## 7. StakingRegistry

- **Vault record:** `{vault, asset, rewardToken, lockDuration, version, createdAt}`. Status is not duplicated; the vault is the source of truth.
- **Lookups:** `allVaults()`, `vaultsOf(asset)`, `isVault(addr)`.
- **Token policy:** per-token status `Unknown | Allowed | Denied`. Creating a vault requires both tokens `Allowed`. `Denied` covers fee-on-transfer, rebasing, ERC777 tokens. Creation also checks code existence and sane decimals.
- **Implementation:** `currentImplementation` and a version counter; changes affect only new vaults.
- **Router:** `trustedRouter` (admin-set).
- **Duplicates:** multiple vaults per token allowed (for example different lock durations), distinguished by a salt.
- **Duration bounds:** `minRewardsDuration`, `maxRewardsDuration` defaults.

### Roles (OpenZeppelin AccessControl)

| Role | Held by | Can | Cannot |
|---|---|---|---|
| Admin | Timelock | Set implementation, router, token policy, shut down a vault, grant roles | Move user funds |
| Vault creator | Timelock or multisig | Create vaults, set each vault's reward manager | Change an existing vault's code |
| Reward manager (per vault) | Set at creation | Fund rewards, set duration (no active period) | Pull funded rewards |
| Guardian | Separate fast multisig key | Pause deposits | Shut down, withdraw, change parameters |

Worst-case admin action is a delayed, visible shutdown that lifts locks so everyone can exit.

## 8. Periphery

### StakingRouter (stateless)
- `depositWithPermit(vault, assets, deadline, v, r, s)`: the permit call is in `try/catch` so a front-run permit cannot grief.
- `multicall`: bundles actions (deposit+claim, exit+deposit for migration).
- `claimAll(vaults[])`, `exitAll(vaults[])`.
- Validates every vault with `registry.isVault`; exact-amount approvals, reset after use; holds no funds between calls.

### StakingLens (read-only)
- `vaultInfo(vault)`: asset, reward token, TVL, reward rate, period end, lock, state.
- `userPosition(vault, user)`: shares, assets, earned, `lockedUntil`, `canWithdraw`.
- `positions(user, start, count)`: paginated across vaults.
- Raw rates only; no USD APR.

## 9. Scenarios the core must handle

| Scenario | Handling |
|---|---|
| ERC-4626 inflation attack | Internal `totalStaked`; donations ignored |
| Fee-on-transfer / rebasing / ERC777 tokens | Registry denylist plus balance-delta checks |
| `rewardToken == asset` | Separate accounting; solvency check excludes principal |
| Stream with zero stakers | Stream pauses, nothing lost |
| Pause | Blocks deposits only; withdrawals never blocked |
| Blacklisted recipient (USDC) | `claim(receiver)` and `withdraw` to a different receiver |
| Stray or donated tokens | `sweep` that cannot touch principal or reserved rewards |
| Third-party lock extension or bypass | Deposit-on-behalf rule (5.3) |
| Share transfer to dodge locks | Non-transferable shares (5.4) |
| No-return tokens (USDT) | `SafeERC20` |
| Rounding | Always down, in vault's favour |
| Compromised admin key | Timelock delay; roles cannot touch principal |
| Compromised guardian key | Can only pause deposits |
| Compromised reward manager | Can only fund; funded rewards cannot be withdrawn |

## 10. Testing strategy

- **Unit:** every function, every revert path, every state transition.
- **Fuzz:** amounts, timing, and sequences of deposit, withdraw, claim, fund.
- **Invariants** (handler-based, extending the existing suite):
  1. Reward balance covers everything owed plus the unstreamed remainder.
  2. Asset balance >= `totalStaked`; `totalStaked` == deposits - withdrawals.
  3. Sum of user shares == `totalSupply`.
  4. Claimed + owed <= funded.
  5. `rewardPerShare` never decreases.
  6. No account can withdraw more than it deposited.
  7. After lock expiry or shutdown, every holder can withdraw full principal.
  8. Pausing never blocks withdrawals.
  9. Shares cannot be transferred.
  10. Only authorised roles can call admin functions.
- **Weird-token mocks:** fee-on-transfer, rebasing, ERC777, reverting transfer, no-return, blacklisting.
- **Fork tests:** real USDC, USDT, DAI.
- **Mutation testing** on the vault core.
- **CI:** build, tests, Slither, coverage, gas snapshots, format.
- **Deployment:** scripts with Etherscan verification and a testnet rehearsal.

## 11. Repo layout

```
src/   vault/ registry/ periphery/ interfaces/ libraries/
test/  unit/ fuzz/ invariant/ fork/ mocks/
script/  deploy + verify
docs/superpowers/specs/
```

Legacy: tag the current state `v0-legacy`, then remove the old `StakingProtocol`, strategies, proxy and factory from `src/` once the vault replaces them. Git history retains them.

## 12. Build order (separate plans)

1. **StakingVault** with reward stream, lockup, lifecycle and invariants (core, most risk).
2. **StakingRegistry**, roles, timelock wiring, token policy.
3. **StakingRouter** and **StakingLens**.
4. Deployment scripts, CI, testnet rehearsal.

## 13. Future versions (extension points only)

- **NFT boost:** an `IBoostModule` giving a per-user reward weight, sourced from the vault's own records, never an open setter. Vault would read `weightOf(user)` when computing shares-for-rewards.
- **Auto-compounding:** a separate vault type whose share price grows via harvest-and-restake; needs a swap integration and slippage protection.
- **Vesting:** a `RewardVesting` helper that receives rewards and releases them linearly; the vault stays unchanged.

## 14. Open items (defaults proposed)

| Item | Default |
|---|---|
| Target chain | Ethereum-style EVM; testnet rehearsal first |
| Timelock delay | 48h mainnet, short on testnet |
| Rewards duration bounds | min 1 day, max 365 days |
| Pragma | `^0.8.20` for all new code |
| Audit | Required before any real funds |
