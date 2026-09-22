// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import {Test} from "forge-std/Test.sol";
import {StakingProtocol} from "../../../contracts/core/StakingProtocol.sol";
import {SampleERC20} from "../../../contracts/test/SampleERC20.sol";

/// @notice The fuzzer calls these functions in random order, with random args, as random actors.
/// Infrastructure is written. Action bodies are yours (TODOs).
contract StakingHandler is Test {
    StakingProtocol public staking;
    address public admin;
    address[] public actors;
    address internal currentActor;

    // ---- vacuous-pass detector: an invariant that never reaches the code proves nothing ----
    mapping(bytes32 => uint256) public calls;

    // ---- flags the invariants read ----
    bool public panicSeen;   // any handler call reverted with a Panic(uint256)
    bool public exitFailed;  // an actor with stake > 0 could not emergencyWithdraw

    // ---- ghost state: YOU decide names and updates ----
    // Likely needs: per-pool tokens really received / really returned, per-actor rewards paid,
    // expectedOwner, timestamp of each actor's last stake/claim per pool.

    modifier useActor(uint256 seed) {
        currentActor = actors[bound(seed, 0, actors.length - 1)];
        vm.startPrank(currentActor);
        _;
        vm.stopPrank();
    }

    constructor(StakingProtocol _staking, address _admin, address[] memory _actors) {
        staking = _staking;
        admin = _admin;
        actors = _actors;
    }

    // ------------------------------------------------------------------
    // USER ACTIONS
    // ------------------------------------------------------------------

    function stake(uint256 actorSeed, uint256 poolSeed, uint256 amount) external useActor(actorSeed) {
        calls["stake"]++;
        uint256 poolId = _pool(poolSeed);
        // TODO(1): bound `amount`. What range would a real user try? What range can the FUZZER try?
        // TODO(2): mint + approve so the call is not rejected on trivial grounds
        // TODO(3): try staking.stakeToken(...) { update ghost } catch (bytes memory err) { _checkPanic(err); }
        poolId; amount;
    }

    function claim(uint256 actorSeed, uint256 poolSeed, bool unstake) external useActor(actorSeed) {
        calls["claim"]++;
        uint256 poolId = _pool(poolSeed);
        // TODO: snapshot reward-token balance before/after so ghost tracks what was ACTUALLY paid
        // TODO: same try/catch + _checkPanic pattern
        poolId; unstake;
    }

    /// Liveness probe: an actor with a stake must always be able to leave.
    function exitProbe(uint256 actorSeed, uint256 poolSeed) external useActor(actorSeed) {
        calls["exitProbe"]++;
        uint256 poolId = _pool(poolSeed);
        // TODO: if actor's stakeAmount > 0, call emergencyWithdraw in try/catch.
        //       On revert set exitFailed = true. On success update ghost (principal returned).
        poolId;
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
    // ADMIN + HOSTILE ACTIONS
    // ------------------------------------------------------------------

    function adminAction(uint256 seed, uint256 value) external {
        calls["adminAction"]++;
        // TODO: as `admin`, pick from: setCliff, setProtocolPaused, setPoolPaused, setPoolStatus,
        //       transferOwnership (update expectedOwner ghost if it succeeds)
        seed; value;
    }

    /// A non-owner tries every external function on the protocol, factory and strategies.
    function outsiderCallsEverything(uint256 actorSeed, uint256 fnSeed, uint256 arg) external useActor(actorSeed) {
        calls["outsider"]++;
        // TODO: for each external function reachable by an outsider, try it with fuzzed args.
        //       Ghost the state you need so INV-5 and INV-6 can detect a change.
        fnSeed; arg;
    }

    // ------------------------------------------------------------------
    // HELPERS
    // ------------------------------------------------------------------

    function _pool(uint256 seed) internal view returns (uint256) {
        return bound(seed, 1, staking.poolCount());
    }

    function _checkPanic(bytes memory err) internal {
        if (err.length >= 4 && bytes4(err) == 0x4e487b71) panicSeen = true; // Panic(uint256)
    }

    function actorCount() external view returns (uint256) {
        return actors.length;
    }
}
