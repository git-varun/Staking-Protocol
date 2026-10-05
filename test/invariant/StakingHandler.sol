// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import {Test} from "forge-std/Test.sol";
import {StakingProtocol} from "../../src/core/StakingProtocol.sol";
import {MockERC20} from "../mocks/MockERC20.sol";

contract StakingHandler is Test {
    StakingProtocol public staking;
    address public admin;
    address[] public actors;
    address internal currentActor;

    mapping(bytes32 => uint256) public calls;

    // ---- flags ----
    bool public panicSeen;
    bool public exitFailed;
    bool public unauthorizedRateChange; // set true if a non-owner path changed anything rate-affecting

    // ---- ghosts ----
    address public expectedOwner;
    mapping(uint256 => uint256) public ghost_transferredIn;   // per pool, staking-token in
    mapping(uint256 => uint256) public ghost_transferredOut;  // per pool, staking-token out
    mapping(address => mapping(uint256 => uint256)) public ghost_rewardsPaid; // actor -> poolId -> reward total

    modifier useActor(uint256 seed) {
        currentActor = actors[bound(seed, 0, actors.length - 1)];
        vm.startPrank(currentActor);
        _;
        vm.stopPrank();
    }

    constructor(StakingProtocol _staking, address _admin, address[] memory _actors) {
        staking = _staking;
        admin = _admin;
        expectedOwner = _admin;
        actors = _actors;
    }

    // ------------------------------------------------------------------
    // USER ACTIONS
    // ------------------------------------------------------------------

    function stake(uint256 actorSeed, uint256 poolSeed, uint256 amount) external useActor(actorSeed) {
        calls["stake"]++;
        uint256 poolId = _pool(poolSeed);
        amount = bound(amount, 1, 1_000_000e18);

        (address stakingToken, , , ) = staking.pools(poolId);
        MockERC20(stakingToken).mint(currentActor, amount);
        MockERC20(stakingToken).approve(address(staking), amount);

        // stakeToken() no longer auto-pays a pending reward on restake — it now requires
        // stakeAmount == 0 (fresh position) or no pending reward before accepting more stake.
        // A restake attempt while reward is pending should REVERT; that's the fix working,
        // not a bug to route around.
        (uint96 stakedBefore, , ) = staking.stakes(currentActor, poolId);
        uint256 pendingBefore = stakedBefore > 0 ? staking.fetchUnclaimedReward(poolId) : 0;

        try staking.stakeToken(poolId, amount) {
            ghost_transferredIn[poolId] += amount;

            // Postcondition on the new guard: if this succeeded on top of an existing position,
            // there must not have been a pending reward. If this ever fires, the require() isn't
            // checking what you think it's checking — wrong pool, stale read, wrong comparator.
            if (stakedBefore > 0) {
                assertEq(pendingBefore, 0, "stake succeeded despite a pending reward; restake guard is broken");
            }
        } catch (bytes memory err) {
            _checkPanic(err);
        }
    }

    function claim(uint256 actorSeed, uint256 poolSeed, bool unstake) external useActor(actorSeed) {
        calls["claim"]++;
        uint256 poolId = _pool(poolSeed);

        (uint96 stakedBefore, uint64 stakeTimeBefore, ) = staking.stakes(currentActor, poolId);
        if (stakedBefore == 0) return; // nothing to claim — don't waste a fuzz run on a guaranteed revert

        (address stakingToken, address rewardToken, , ) = staking.pools(poolId);
        uint256 rewardBalBefore = MockERC20(rewardToken).balanceOf(currentActor);
        uint256 stakeBalBefore = MockERC20(stakingToken).balanceOf(currentActor);

        try staking.claimRewards(poolId, unstake) {
            uint256 rewardPaid = MockERC20(rewardToken).balanceOf(currentActor) - rewardBalBefore;
            ghost_rewardsPaid[currentActor][poolId] += rewardPaid;

            // INV-7 (cliff) as a per-call postcondition, checked right where the action happens —
            // this is a property of THIS successful call, not persistent state, so it belongs here
            // and not in a separate invariant_ function. See note in StakingInvariants.t.sol.
            assertGe(
                block.timestamp,
                stakeTimeBefore + staking.cliff(),
                "INV-7: reward paid before cliff elapsed"
            );

            if (unstake) {
                uint256 returned = MockERC20(stakingToken).balanceOf(currentActor) - stakeBalBefore;
                ghost_transferredOut[poolId] += returned;
            }
        } catch (bytes memory err) {
            _checkPanic(err);
        }
    }

    /// Liveness probe: an actor with a stake must always be able to leave via emergencyWithdraw.
    function exitProbe(uint256 actorSeed, uint256 poolSeed) external useActor(actorSeed) {
        calls["exitProbe"]++;
        uint256 poolId = _pool(poolSeed);

        (uint96 amt, , ) = staking.stakes(currentActor, poolId);
        if (amt == 0) return;

        (address stakingToken, , , ) = staking.pools(poolId);
        uint256 balBefore = MockERC20(stakingToken).balanceOf(currentActor);

        try staking.emergencyWithdraw(poolId) {
            uint256 returned = MockERC20(stakingToken).balanceOf(currentActor) - balBefore;
            ghost_transferredOut[poolId] += returned;
        } catch (bytes memory err) {
            _checkPanic(err);
            exitFailed = true; // had a stake, tried to leave, couldn't — that's the INV-8 violation
        }
    }

    // ------------------------------------------------------------------
    // TIME
    // ------------------------------------------------------------------

    function warp(uint256 secondsForward) external {
        calls["warp"]++;
        secondsForward = bound(secondsForward, 1, 730 days);
        vm.warp(block.timestamp + secondsForward);
        vm.roll(block.number + secondsForward / 12 + 1);
    }

    // ------------------------------------------------------------------
    // LEGITIMATE ADMIN ACTIONS (called as the real owner)
    // ------------------------------------------------------------------

    function adminAction(uint256 seed, uint256 value) external {
        calls["adminAction"]++;
        vm.startPrank(admin);
        uint256 poolId = _pool(seed);
        uint256 choice = bound(seed, 0, 4);

        if (choice == 0) {
            try staking.setCliff(bound(value, 1, 365 days)) {} catch {}
        } else if (choice == 1) {
            try staking.setProtocolPaused(value % 2 == 0) {} catch {}
        } else if (choice == 2) {
            try staking.setPoolPaused(poolId, value % 2 == 0) {} catch {}
        } else if (choice == 3) {
            try staking.setPoolStatus(poolId, value % 2 == 0) {} catch {}
        } else {
            address newAdmin = actors[bound(value, 0, actors.length - 1)];
            try staking.transferOwnership(newAdmin) {
                admin = newAdmin;
                expectedOwner = newAdmin; // ghost follows the legitimate transfer
            } catch {}
        }
        vm.stopPrank();
    }

    // ------------------------------------------------------------------
    // HOSTILE ACTIONS — a random actor tries every owner-gated / rate-affecting path
    // ------------------------------------------------------------------

    function outsiderCallsEverything(uint256 actorSeed, uint256 poolSeed, uint256 arg) external useActor(actorSeed) {
        calls["outsider"]++;
        uint256 poolId = _pool(poolSeed);

        if (currentActor != staking.owner()) {
            // owner-gated on the staking contract itself — must always revert
            try staking.setCliff(arg) { unauthorizedRateChange = true; } catch {}
            try staking.setRewardStrategy(poolId, address(uint160(arg))) { unauthorizedRateChange = true; } catch {}
            try staking.setProtocolPaused(arg % 2 == 0) {} catch {}
            try staking.setPoolPaused(poolId, arg % 2 == 0) {} catch {}
            try staking.setPoolStatus(poolId, arg % 2 == 0) {} catch {}
            try staking.transferOwnership(currentActor) {} catch {} // INV-5 catches a success directly

            // the strategy contract behind this pool is a SEPARATE contract with its own access
            // control (or lack of it) — the staking contract's onlyOwner doesn't protect it.
            // Generically probe every external mutating function it exposes:
            address strategy = staking.rewardStrategies(poolId);
            if (strategy != address(0)) {
                (bool ok1, ) = strategy.call(
                    abi.encodeWithSignature("updateNFTBoost(address,uint256)", currentActor, arg)
                );
                if (ok1) unauthorizedRateChange = true;
                // add more abi.encodeWithSignature(...) probes here for any other mutating
                // function a strategy contract exposes, so new strategies stay covered
            }
        }
    }

    // ------------------------------------------------------------------
    // HELPERS
    // ------------------------------------------------------------------

    function _pool(uint256 seed) internal view returns (uint256) {
        return bound(seed, 1, staking.poolCount());
    }

    function _checkPanic(bytes memory err) internal {
        if (err.length >= 4 && bytes4(err) == 0x4e487b71) panicSeen = true;
    }

    function actorCount() external view returns (uint256) {
        return actors.length;
    }

    function actorAt(uint256 i) external view returns (address) {
        return actors[i];
    }
}
