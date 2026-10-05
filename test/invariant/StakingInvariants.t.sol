// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {StakingProtocol} from "../../src/core/StakingProtocol.sol";
import {RewardStrategyFactory} from "../../src/RewardStrategyFactory.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {StakingHandler} from "./StakingHandler.sol";

contract StakingInvariants is Test {
    StakingProtocol public staking;
    RewardStrategyFactory public factory;
    StakingHandler public handler;

    address public admin = makeAddr("admin");
    address[] public actors;

    ERC20Mock public stakingToken;
    ERC20Mock public rewardToken;

    uint256 public constant CLIFF = 7 days;
    uint256 public constant YIELD_PER_SECOND = 1e15; // used for pool metadata; actual math comes from the strategy

    function setUp() public {
        vm.startPrank(admin);

        // --- core deploy ---
        staking = new StakingProtocol();
        staking.initialize(admin, CLIFF);

        stakingToken = new ERC20Mock();
        rewardToken = new ERC20Mock();

        // --- pools: 1 = Linear strategy, 2 = FixedPerBlock strategy ---
        staking.createPool(address(stakingToken), address(rewardToken), YIELD_PER_SECOND);
        staking.createPool(address(stakingToken), address(rewardToken), YIELD_PER_SECOND);

        // --- strategies, via the factory (factory owner == admin here) ---
        factory = new RewardStrategyFactory();
        address linear = factory.deployLinearStrategy(1, YIELD_PER_SECOND);
        address fixedPerBlock = factory.deployFixedPerBlockStrategy(2, 1e15);

        staking.setRewardStrategy(1, linear);
        staking.setRewardStrategy(2, fixedPerBlock);

        // --- fund the protocol's reward inventory the way a real admin would ---
        // claimRewards/stakeToken use plain transfer(), so the STAKING CONTRACT must hold
        // reward tokens directly — minting to admin and forgetting to fund the contract
        // is exactly the kind of setup mistake that produces a false-negative test run.
        rewardToken.mint(address(staking), 10_000_000e18);

        vm.stopPrank();

        // --- actors ---
        actors.push(makeAddr("alice"));
        actors.push(makeAddr("bob"));
        actors.push(makeAddr("carol"));

        // --- wire the fuzzer to only call the handler ---
        handler = new StakingHandler(staking, admin, actors);
        targetContract(address(handler));
    }

    // ------------------------------------------------------------------
    // Diagnostics — read this before trusting ANY green run
    // ------------------------------------------------------------------

    function invariant_callSummary() public view {
        console.log("stake       ", handler.calls("stake"));
        console.log("claim       ", handler.calls("claim"));
        console.log("exitProbe   ", handler.calls("exitProbe"));
        console.log("warp        ", handler.calls("warp"));
        console.log("adminAction ", handler.calls("adminAction"));
        console.log("outsider    ", handler.calls("outsider"));
    }

    // ------------------------------------------------------------------
    // INV-1: internal consistency — totalStaked matches the sum of individual
    // stakeAmounts, read entirely from the CONTRACT's own state (no ghost).
    // This tests the contract against itself: does its own bookkeeping add up.
    // ------------------------------------------------------------------

    function invariant_INV1_conservation() public view {
        uint256 n = handler.actorCount();
        for (uint256 poolId = 1; poolId <= staking.poolCount(); poolId++) {
            uint256 sumStaked;
            for (uint256 i = 0; i < n; i++) {
                (uint256 amt,,) = staking.stakes(handler.actorAt(i), poolId);
                sumStaked += amt;
            }
            (,,, uint256 totalStaked) = staking.pools(poolId);
            assertEq(totalStaked, sumStaked, "INV-1: totalStaked != sum of individual stakes");
        }
    }

    // ------------------------------------------------------------------
    // INV-2: solvency — the contract must physically hold at least what it owes.
    // This is the one that catches "reward token == staking token, rewards eat
    // into principal," which matters here since both pools use the same token
    // for staking and rewards in this setUp.
    // ------------------------------------------------------------------

    function invariant_INV2_solvency() public view {
        for (uint256 poolId = 1; poolId <= staking.poolCount(); poolId++) {
            (address token,,, uint256 totalStaked) = staking.pools(poolId);
            uint256 held = ERC20Mock(token).balanceOf(address(staking));
            assertGe(held, totalStaked, "INV-2: protocol holds less staking-token than it owes");
        }
    }

    // ------------------------------------------------------------------
    // INV-3: contract's internal number matches externally OBSERVED token flow.
    // Independent of INV-1 — this can fail even when INV-1 holds, if a path
    // moves totalStaked without moving real tokens (or vice versa).
    // ------------------------------------------------------------------

    function invariant_INV3_principalInOut() public view {
        for (uint256 poolId = 1; poolId <= staking.poolCount(); poolId++) {
            (,,, uint256 totalStaked) = staking.pools(poolId);
            uint256 netFlow = handler.ghost_transferredIn(poolId) - handler.ghost_transferredOut(poolId);
            assertEq(totalStaked, netFlow, "INV-3: totalStaked diverges from observed transfer flow");
        }
    }

    // ------------------------------------------------------------------
    // INV-4: reward math bound. NOT written as a stateful invariant_ function —
    // it's a pure per-call property (given these inputs, this output), so it
    // belongs in a standalone fuzz test against the strategy contract directly,
    // not threaded through the whole stateful handler. See StrategyMath.t.sol.
    // ------------------------------------------------------------------

    // ------------------------------------------------------------------
    // INV-5: ownership only changes through an owner-authorized path.
    // ------------------------------------------------------------------

    function invariant_INV5_ownership() public view {
        assertEq(staking.owner(), handler.expectedOwner(), "INV-5: owner diverged from the authorized-transfer ghost");
    }

    // ------------------------------------------------------------------
    // INV-6: nothing that feeds reward-rate math is changeable by a non-owner.
    // Flag pattern, not a ghost-equality pattern: outsiderCallsEverything sets
    // the flag the moment any owner-gated OR rate-affecting call unexpectedly
    // succeeds from a non-owner. Simpler than modeling per-strategy ghost state,
    // and it generalizes to strategies added later without new invariant code.
    // ------------------------------------------------------------------

    function invariant_INV6_rateAuthority() public view {
        assertFalse(handler.unauthorizedRateChange(), "INV-6: a non-owner path changed rate-affecting state");
    }

    // ------------------------------------------------------------------
    // INV-7: cliff. NOT a global invariant_ function — it's a postcondition of
    // a specific successful claim, checked inline in StakingHandler.claim()
    // right after the call. Putting it here would mean re-deriving "was the
    // last claim's timing valid" from state the handler already had in hand.
    // ------------------------------------------------------------------

    // ------------------------------------------------------------------
    // INV-8 / INV-9: liveness and robustness flags.
    // ------------------------------------------------------------------

    function invariant_INV8_exitGuarantee() public view {
        assertFalse(handler.exitFailed(), "INV-8: an actor with a stake could not exit");
    }

    function invariant_INV9_noPanics() public view {
        assertFalse(handler.panicSeen(), "INV-9: a handler call reverted with a Panic");
    }
}
