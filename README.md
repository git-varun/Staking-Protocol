# Staking Protocol: Invariant and Fuzz Suite

Target: the `StakingProtocol` that implements `IStakingProtocol` (not the V1 draft), plus the three reward strategies and the factory.
Goal: a stateful invariant suite, fuzz tests, and a gas report. Every failure becomes a `FINDINGS.md` entry. The suite is then mutation-checked.

## Rules
1. **Contracts stay untouched** until a failing sequence is traced by hand and logged in `FINDINGS.md`.
2. **Predict first.** Above each invariant write "This breaks if ____" before the first run.
3. **Trace failures by hand.** Forge prints a shrunk call sequence. Write state before/after each call before you look for the fix.
4. **No vacuous passes.** Read `invariant_callSummary` output. If an action never ran, or always reverted, the green result means nothing.
5. **Do not skim the setUp.** The fuzzer only explores what setUp and the handler allow.

## Scope
In: ERC-20 path (`stakeToken`, `claimRewards`, `emergencyWithdraw`), the 3 strategies through the factory, admin functions, one upgrade-safety test.
Out for now: NFT path, fee-on-transfer tokens, frontends.

## Properties
| ID | Property | Kind |
|----|----------|------|
| INV-1 | `totalStaked` equals the sum of all actor stakes, per pool | accounting |
| INV-2 | staking-token balance held >= `totalStaked`, per pool | solvency |
| INV-3 | tokens actually received minus actually returned == `totalStaked` | accounting (ghost) |
| INV-4 | rewards paid per actor <= independent model max (Linear only) | economic |
| INV-5 | `owner` changes only via an owner-authorized path | access |
| INV-6 | nothing feeding reward-rate math is changeable by a non-owner | access |
| INV-7 | no reward leaves before the cliff has elapsed | behavioral |
| INV-8 | any actor with a stake can always exit | liveness |
| INV-9 | no handler call reverts with a Panic | robustness |

## Steps
0. **Baseline.** Split the flattened file into your repo layout (keep V1 out of `contracts/`; it will not compile alongside the interface). `forge build`. Write one happy-path test to prove setUp.
1. INV-1 to INV-3 plus `stake`, `claim`, `exitProbe`, `warp` in the handler. Run, read the call summary, trace failures.
2. INV-5, INV-6 plus `adminAction`, `outsiderCallsEverything`.
3. INV-4, INV-7, INV-8, INV-9.
4. Fuzz tests (not invariants) on strategy math with bounded inputs.
5. **Upgrade safety.** Run `forge inspect <Contract> storage-layout` for the V1 and current versions. Predict what a proxy pointing at the current version does to state written under V1. Prove it with a test.
6. Gas: `forge test --gas-report`. Save the baseline, do a gas pass, save the after numbers.
7. Mutation check (after your fixes): reintroduce each fixed bug one at a time, confirm at least one invariant fails.

## FINDINGS.md format
ID, invariant that caught it, shrunk sequence, root cause, severity, fix.
