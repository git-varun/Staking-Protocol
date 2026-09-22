// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "../interfaces/IRewardStrategy.sol";


// NFT Boosted Strategy
contract NFTBoostedStrategy is IRewardStrategy {
    uint256 public baseYield;
    uint256 public boostMultiplier;
    mapping(address => uint256) public nftBalance;

    constructor(uint256 _baseYield, uint256 _boostMultiplier) {
        baseYield = _baseYield;
        boostMultiplier = _boostMultiplier;
    }

    function calculateReward(
        address user,
        uint256,
        uint256 stakedAmount,
        uint256 lastStakeTime
    ) external view override returns (uint256 rewardAmount) {
        uint256 timeDiff = block.timestamp - lastStakeTime;
        uint256 bonusFactor = 1e18 + (nftBalance[user] * boostMultiplier);
        rewardAmount = (stakedAmount * timeDiff * baseYield * bonusFactor) / (31536000 * 1e18);
    }

    function updateNFTBoost(address user, uint256 count) external {
        nftBalance[user] = count;
    }
}