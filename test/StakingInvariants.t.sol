// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {StakingProtocol} from "../../../contracts/core/StakingProtocol.sol";
import {StakingHandler} from "../handlers/StakingHandler.sol";

contract StakingInvariants is Test {
    StakingProtocol staking;
    StakingHandler handler;
    address admin = makeAddr("admin");
    address[] actors;

    function setUp() public {
        // TODO(setUp-1): deploy StakingProtocol DIRECTLY (no proxy yet), initialize(admin, cliff)
        // TODO(setUp-2): tokens: at least a staking token and a reward token (SampleERC20.mint is public)
        // TODO(setUp-3): create >= 2 pools. Pick configs createPool() PERMITS, not just ones you'd deploy.
        //                The fuzzer only tests configurations you give it.
        // TODO(setUp-4): strategies via RewardStrategyFactory (Linear, FixedPerBlock, NFTBoosted),
        //                attach with setRewardStrategy. Spread them across pools.
        // TODO(setUp-5): fund the reward inventory the way a real admin would
        // TODO(setUp-6): actors (3), handler, targetContract(address(handler)), targetSelector(...)
    }

    // Prints how often each handler action actually ran. Read this before trusting any green run.
    function invariant_callSummary() public view {
        console.log("stake", handler.calls("stake"));
        console.log("claim", handler.calls("claim"));
        console.log("exitProbe", handler.calls("exitProbe"));
        console.log("warp", handler.calls("warp"));
        console.log("adminAction", handler.calls("adminAction"));
        console.log("outsider", handler.calls("outsider"));
    }

    // Before running each one, write a comment: "This breaks if ____".

    function invariant_INV1_conservation() public {
        fail("TODO INV-1: pool.totalStaked == sum of every actor's stakeAmount, per pool");
    }

    function invariant_INV2_solvency() public {
        fail("TODO INV-2: staking-token balance held by protocol >= totalStaked, per pool");
    }

    function invariant_INV3_principalInOut() public {
        fail("TODO INV-3: tokens actually received - tokens actually returned == totalStaked");
    }

    function invariant_INV4_rewardBound() public {
        fail("TODO INV-4: rewards paid per actor <= an independent model's maximum (Linear pools only)");
    }

    function invariant_INV5_ownership() public {
        fail("TODO INV-5: staking.owner() == handler's expectedOwner ghost");
    }

    function invariant_INV6_rateAuthority() public {
        fail("TODO INV-6: nothing that feeds reward-rate math changes unless owner did it");
    }

    function invariant_INV7_cliff() public {
        fail("TODO INV-7: no reward leaves before cliff elapsed since that actor's last stake/claim");
    }

    function invariant_INV8_exitGuarantee() public {
        assertFalse(handler.exitFailed(), "an actor with a stake could not exit");
    }

    function invariant_INV9_noPanics() public {
        assertFalse(handler.panicSeen(), "a handler call reverted with a Panic");
    }
}
