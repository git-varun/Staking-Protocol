// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "../interfaces/IRewardStrategy.sol";

// Fixed per block reward
contract FixedPerBlockStrategy is IRewardStrategy {
    uint256 public fixedReward;

    constructor(uint256 _fixedReward) {
        fixedReward = _fixedReward;
    }

    function calculateReward(
        address,
        uint256,
        uint256,
        uint256 lastStakeTime
    ) external view override returns (uint256 rewardAmount) {
        uint256 blocksPassed = block.number - (lastStakeTime / 12); // rough block estimate
        rewardAmount = blocksPassed * fixedReward;
    }
}