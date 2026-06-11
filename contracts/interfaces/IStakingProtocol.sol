// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title IStakingProtocol
/// @notice Interface for the staking protocol
interface IStakingProtocol {
    // =============================================================================
    // STRUCTURES
    // =============================================================================
    
    /// @notice Pool information structure
    struct PoolInfo {
        address stakingToken;      // ERC20 token to stake
        address rewardToken;       // ERC20 reward token
        uint256 yieldPerSecond;    // Reward per second
        uint256 totalStaked;       // Total amount staked in pool
    }

    /// @notice User staking information
    struct StakingInfo {
        uint96 stakeAmount;        // Amount staked
        uint64 stakeTime;          // Last stake/claim timestamp
        bool autoCompound;         // Auto-compound flag (reserved)
    }

    /// @notice NFT staking information
    struct NFTStakeInfo {
        uint256 tokenId;           // NFT token ID
        uint256 stakeTime;         // Stake timestamp
    }

    // =============================================================================
    // EVENTS
    // =============================================================================
    
    event Staked(address indexed user, uint256 amount, uint256 indexed poolId, uint256 time);
    event Claimed(address indexed user, uint256 reward, uint256 indexed poolId, uint256 time, bool unstake);
    event EmergencyWithdraw(address indexed user, uint256 indexed poolId, uint256 amount, uint256 time);
    event PoolCreated(uint256 indexed poolId, address stakingToken, address rewardToken, uint256 yieldPerSecond);
    event NFTStaked(address indexed user, uint256 indexed poolId, uint256 tokenId, uint256 time);
    event NFTUnstaked(address indexed user, uint256 indexed poolId, uint256 tokenId, uint256 time);

    // =============================================================================
    // ADMIN FUNCTIONS
    // =============================================================================
    
    function setCliff(uint256 _cliff) external;
    function setProtocolPaused(bool _paused) external;
    function setPoolPaused(uint256 poolId, bool state) external;
    function setPoolStatus(uint256 poolId, bool active) external;
    function createPool(address stakingToken, address rewardToken, uint256 yieldPerSecond) external;
    function setRewardStrategy(uint256 poolId, address strategy) external;
    function transferOwnership(address newOwner) external;

    // =============================================================================
    // USER FUNCTIONS - ERC20 STAKING
    // =============================================================================
    
    function stakeToken(uint256 poolId, uint256 amount) external;
    function claimRewards(uint256 poolId, bool unStaking) external;
    function emergencyWithdraw(uint256 poolId) external;

    // =============================================================================
    // USER FUNCTIONS - ERC721 STAKING
    // =============================================================================
    
    function stakeNFT(uint256 poolId, address nftAddress, uint256 tokenId) external;
    function unstakeNFT(uint256 poolId, address nftAddress, uint256 tokenId) external;

    // =============================================================================
    // VIEW FUNCTIONS
    // =============================================================================
    
    function fetchUnclaimedReward(uint256 poolId) external view returns (uint256);
    function fetchUnclaimedNFTReward(uint256 poolId, uint256 tokenId) external view returns (uint256);
    function getStakeInfo(address user, uint256 poolId) external view returns (StakingInfo memory);
    function getPoolInfo(uint256 poolId) external view returns (PoolInfo memory);
    function getRewardStrategy(uint256 poolId) external view returns (address);
}
