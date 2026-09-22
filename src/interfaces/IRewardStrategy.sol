// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

interface IRewardStrategy {
    /**
     * @notice Calculate reward based on inputs provided by the staking contract
     * @param user The address of the user
     * @param poolId The staking pool identifier
     * @param stakedAmount The user's staked token amount
     * @param lastStakeTime Timestamp of user's last stake or claim
     * @return rewardAmount The calculated claimable reward
     */
    function calculateReward(
        address user,
        uint256 poolId,
        uint256 stakedAmount,
        uint256 lastStakeTime
    ) external view returns (uint256 rewardAmount);
}