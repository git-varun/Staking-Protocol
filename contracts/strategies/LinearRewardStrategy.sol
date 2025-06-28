// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "./IRewardStrategy.sol";

// Linear Strategy
contract LinearRewardStrategy is IRewardStrategy {
    uint256 public yieldPerSecond;

    constructor(uint256 _yieldPerSecond) {
        yieldPerSecond = _yieldPerSecond;
    }

    function calculateReward(
        address,
        uint256,
        uint256 stakedAmount,
        uint256 lastStakeTime
    ) external view override returns (uint256 rewardAmount) {
        uint256 timeDiff = block.timestamp - lastStakeTime;
        rewardAmount = (stakedAmount * timeDiff * yieldPerSecond) / 31536000;
    }
}