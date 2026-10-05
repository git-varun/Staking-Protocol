// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {StakingProtocol} from "../../../src/core/StakingProtocol.sol";
import {StakingConstants} from "../../../src/libraries/StakingConstants.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

contract StakingProtocolTest is Test {
    StakingProtocol public stakeProtocol;

    ERC20Mock public stakingToken;
    ERC20Mock public rewardToken;

    address private owner;
    address private attacker;
    address private user;

    uint256 private constant cliff = 2 days;
    uint256 private constant YPS = 100 wei;

    event PoolCreated(uint256 indexed poolId, address stakingToken, address rewardToken, uint256 yieldPerSecond);

    function setUp() public {
        owner = makeAddr("owner");
        attacker = makeAddr("attacker");
        user = makeAddr("user");

        stakeProtocol = new StakingProtocol();
        stakeProtocol.initialize(owner, cliff);

        stakingToken = new ERC20Mock();
        rewardToken = new ERC20Mock();

        stakingToken.mint(user, 10 ether);
    }

    function _createDefaultPool() private {
        vm.prank(owner);
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
        vm.prank(owner);
        vm.expectRevert(bytes(StakingConstants.ERROR_ZERO_ADDRESS));
        stakeProtocol.createPool(address(0), address(rewardToken), YPS);
    }

    function test_CreatePool_RevertWhenZeroRewardToken() public {
        vm.prank(owner);
        vm.expectRevert(bytes(StakingConstants.ERROR_ZERO_ADDRESS));
        stakeProtocol.createPool(address(stakingToken), address(0), YPS);
    }

    function _defaultStake() private {
        _createDefaultPool();
        uint256 poolId = stakeProtocol.poolCount();
        uint256 amount = 10 ether;

        vm.startPrank(user);
        stakingToken.approve(address(stakeProtocol), amount);
        stakeProtocol.stakeToken(poolId, amount);
        vm.stopPrank();
    }

    function test_stake() public {
        uint256 stakedTime = block.timestamp;
        _defaultStake();
        (,,, uint256 totalStaked) = stakeProtocol.pools(1);
        (uint256 stakeAmount, uint64 stakeTime, bool autoCompound) = stakeProtocol.stakes(user, 1);

        console.log(totalStaked, stakeAmount, stakedTime);

        assertEq(totalStaked, 10 ether);
        assertEq(stakeAmount, uint96(10 ether));
        assertEq(stakedTime, uint64(stakeTime));
        assertEq(autoCompound, false);
    }
}
