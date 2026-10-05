// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {LinearRewardStrategy} from "../../src/strategies/LinearRewardStrategy.sol";

/// @notice INV-4, as a plain fuzz test: for the Linear strategy, calculateReward() must
/// exactly match an independently-written formula for ANY bounded input. This is a pure
/// function property — same inputs always give the same output — so a fuzz test (many
/// random inputs, checked in isolation) is the right tool, not a stateful invariant
/// (which is for properties that must hold across a SEQUENCE of state-changing calls).
contract StrategyMathTest is Test {
    LinearRewardStrategy public strategy;
    uint256 public constant YIELD_PER_SECOND = 1e15;

    function setUp() public {
        strategy = new LinearRewardStrategy(YIELD_PER_SECOND);
    }

    function testFuzz_linearReward_matchesIndependentModel(uint256 stakedAmount, uint256 elapsed) public view {
        stakedAmount = bound(stakedAmount, 0, 10_000_000e18);
        elapsed = bound(elapsed, 0, 4 * 365 days);

        uint256 lastStakeTime = block.timestamp > elapsed ? block.timestamp - elapsed : 0;
        // guard against underflow in the strategy's own `block.timestamp - lastStakeTime`
        vm.assume(block.timestamp >= lastStakeTime);

        uint256 actual = strategy.calculateReward(address(0), 0, stakedAmount, lastStakeTime);

        // independent re-derivation of the same formula, written without looking at
        // the strategy's implementation line-by-line — the point is to catch a mistake
        // in ONE of the two derivations, not to copy the same bug into both
        uint256 expected = (stakedAmount * (block.timestamp - lastStakeTime) * YIELD_PER_SECOND) / 31536000;

        assertEq(actual, expected, "Linear strategy diverges from independent model");
    }

    /// A specific case worth naming rather than leaving to chance: does the yearly
    /// yield actually come out to yieldPerSecond * seconds-in-year, for a clean 1-year stake?
    function test_linearReward_oneYear_wholeToken() public {
        uint256 staked = 1 ether;
        vm.warp(400 days);
        uint256 reward = strategy.calculateReward(address(0), 0, staked, block.timestamp - 365 days);
        console.log(reward);
        uint256 expected = (staked * 365 days * YIELD_PER_SECOND) / 31536000;
        assertEq(reward, expected, "trace this by hand, don't trust the assert");
    }
}
