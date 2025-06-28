// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

interface IStakingProtocol {
    struct PoolInfo {
        address stakingToken;
        address rewardToken;
        uint256 yieldPerSecond;
        uint256 totalStaked;
    }

    struct StakingInfo {
        uint96 stakeAmount;
        uint64 stakeTime;
        bool autoCompound;
    }

    struct NFTStakeInfo {
        uint256 tokenId;
        uint256 stakeTime;
    }

    event Staked(address indexed user, uint256 amount, uint256 poolId, uint256 time);
    event Claimed(address indexed user, uint256 reward, uint256 poolId, uint256 time, bool unstake);
    event EmergencyWithdraw(address indexed user, uint256 poolId, uint256 amount, uint256 time);
    event PoolCreated(uint256 indexed poolId, address stakingToken, address rewardToken, uint256 yieldPerSecond);


    // Admin
    function setCliff(uint256 _cliff) external;
    function changeStakingStatus(bool status) external;
    function changePoolStatus(uint256 poolId, bool status) external;
    function createPool(address stakingToken, address rewardToken, uint256 yieldPerSecond) external;
    function setRewardStrategy(uint256 poolId, address strategy) external;

    // Stake / Claim / Info
    function stakeToken(uint256 poolId, uint256 amount) external;
    function claimToken(uint256 poolId, bool unStaking) external;
    function stakeNFT(uint256 poolId, address nftAddress, uint256 tokenId) external;
    function unstakeNFT(uint256 poolId, address nftAddress, uint256 tokenId) external;
    function fetchUnclaimedReward(uint256 poolId) external view returns (uint256);
    function fetchUnclaimedNFTReward(uint256 poolId, uint256 tokenId) external view returns (uint256);
    function stakeInfo(address user, uint256 poolId) external view returns (StakingInfo memory);
    function fetchPoolInfo(uint256 poolId) external view returns (PoolInfo memory);
}
