// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {StakingProtocol} from "../../../src/core/StakingProtocol.sol";
import {IStakingProtocol} from "../../../src/interfaces/IStakingProtocol.sol";
import {StakingConstants} from "../../../src/libraries/StakingConstants.sol";
import {MockERC20} from "../../mocks/MockERC20.sol";
import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

contract StakingProtocolTest is Test {
    StakingProtocol public stakeProtocol;

    MockERC20 public stakingToken;
    MockERC20 public rewardToken;

    address private OWNER;
    address private ATTACKER;
    address private USER;

    uint256 private constant cliff = 2 days;
    uint256 private constant YPS = 100 wei;

    event PoolCreated(uint256 indexed poolId, address stakingToken, address rewardToken, uint256 yieldPerSecond);

    function setUp() public {
        OWNER = makeAddr("OWNER");
        ATTACKER = makeAddr("ATTACKER");
        USER = makeAddr("USER");

        stakeProtocol = new StakingProtocol();
        stakeProtocol.initialize(OWNER, cliff);

        stakingToken = new MockERC20("stakeToken", "ST");
        rewardToken = new MockERC20("rewardToken", "RT");

        stakingToken.mint(USER, 10 ether);
    }

    function _createDefaultPool() private {
        vm.prank(OWNER);
        stakeProtocol.createPool(address(stakingToken), address(rewardToken), YPS);
    }

    function test_CreatePool() public {
        _createDefaultPool();

        (address st, address rt, uint256 yps, uint256 totalStaked) = stakeProtocol.pools(1);
        assertEq(st, address(stakingToken));
        assertEq(rt, address(rewardToken));
        assertEq(yps, YPS);
        assertEq(totalStaked, 0);
        assertTrue(stakeProtocol.poolStatus(1));
    }

    function test_CreatePool_UpdatePoolCount() public {
        uint256 before = stakeProtocol.poolCount();

        _createDefaultPool();

        assertEq(stakeProtocol.poolCount(), before + 1);
    }

    function test_CreatePool_EmitsEvent() public {
        vm.expectEmit(true, false, false, true);
        emit PoolCreated(1, address(stakingToken), address(rewardToken), YPS);

        _createDefaultPool();
    }

    function test_CreatePool_RevertWhenNotOwner() public {
        vm.prank(makeAddr("attacker"));
        vm.expectRevert(bytes(StakingConstants.ERROR_NOT_OWNER));
        stakeProtocol.createPool(address(stakingToken), address(rewardToken), YPS);
    }

    function test_CreatePool_RevertWhenZeroStakingToken() public {
        vm.prank(OWNER);
        vm.expectRevert(bytes(StakingConstants.ERROR_ZERO_ADDRESS));
        stakeProtocol.createPool(address(0), address(rewardToken), YPS);
    }

    function test_CreatePool_RevertWhenZeroRewardToken() public {
        vm.prank(OWNER);
        vm.expectRevert(bytes(StakingConstants.ERROR_ZERO_ADDRESS));
        stakeProtocol.createPool(address(stakingToken), address(0), YPS);
    }

    function _defaultStake() private {
        _createDefaultPool();
        uint256 poolId = stakeProtocol.poolCount();
        uint256 amount = 10 ether;

        vm.startPrank(USER);
        stakingToken.approve(address(stakeProtocol), amount);
        stakeProtocol.stakeToken(poolId, amount);
        vm.stopPrank();
    }

    function test_stake() public {
        uint256 stakedTime = block.timestamp;
        _defaultStake();
        (,,,uint256 totalStaked) = stakeProtocol.pools(1);
        (uint96 stakeAmount, uint64 stakeTime, bool autoCompound) = stakeProtocol.stakes(USER, 1);

        console.log(totalStaked, stakeAmount, stakedTime);

        assertEq(totalStaked, 10 ether);
        assertEq(stakeAmount, uint96(10 ether));
        assertEq(stakedTime, uint64(stakeTime));
        assertEq(autoCompound, false);
    }
}
