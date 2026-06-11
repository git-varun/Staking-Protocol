// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "../interfaces/IStakingProtocol.sol";
import "../interfaces/IRewardStrategy.sol";
import "../libraries/StakingConstants.sol";

/// @title StakingProtocol
/// @notice Main staking contract supporting ERC20 and ERC721 tokens
/// @dev Implements upgradeable proxy pattern with customizable reward strategies
contract StakingProtocol is Context, ReentrancyGuard, IStakingProtocol {
    // =============================================================================
    // STATE VARIABLES
    // =============================================================================
    
    address public owner;
    uint256 public poolCount;
    uint256 public cliff;
    bool public paused;

    // Mappings
    mapping(uint256 => PoolInfo) public pools;
    mapping(address => mapping(uint256 => StakingInfo)) public stakes;
    mapping(uint256 => bool) public poolStatus;
    mapping(uint256 => bool) public poolPaused;
    mapping(uint256 => address) public nftContractPerPool;
    mapping(address => mapping(uint256 => mapping(uint256 => NFTStakeInfo))) public nftStakes;
    mapping(uint256 => address) public rewardStrategies;

    // Reserved storage space for upgradeability
    uint256[40] private __gap;

    // =============================================================================
    // EVENTS
    // =============================================================================
    
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event ProtocolInitialized(address indexed owner, uint256 cliffDuration);
    event CliffUpdated(uint256 newCliff);
    event ProtocolPaused(bool state);
    event PoolPaused(uint256 indexed poolId, bool state);

    // =============================================================================
    // MODIFIERS
    // =============================================================================
    
    modifier onlyOwner() {
        require(msg.sender == owner, StakingConstants.ERROR_NOT_OWNER);
        _;
    }

    modifier whenNotPaused() {
        require(!paused, StakingConstants.ERROR_PROTOCOL_PAUSED);
        _;
    }

    modifier whenPoolActive(uint256 poolId) {
        require(!paused, StakingConstants.ERROR_PROTOCOL_PAUSED);
        require(poolId > 0 && poolId <= poolCount, StakingConstants.ERROR_INVALID_POOL);
        require(poolStatus[poolId], StakingConstants.ERROR_POOL_INACTIVE);
        require(!poolPaused[poolId], StakingConstants.ERROR_POOL_PAUSED);
        _;
    }

    // =============================================================================
    // INITIALIZER
    // =============================================================================
    
    bool private _initialized;

    /// @notice Initialize the staking protocol (for proxy pattern)
    /// @param _owner Address of the protocol owner
    /// @param _cliff Cliff period in seconds
    function initialize(address _owner, uint256 _cliff) external {
        require(!_initialized, StakingConstants.ERROR_ALREADY_INITIALIZED);
        require(_owner != address(0), StakingConstants.ERROR_ZERO_ADDRESS);
        
        owner = _owner;
        cliff = _cliff;
        poolCount = 0;
        paused = false;
        _initialized = true;
        
        emit OwnershipTransferred(address(0), _owner);
        emit ProtocolInitialized(_owner, _cliff);
    }

    // =============================================================================
    // ADMIN FUNCTIONS
    // =============================================================================
    
    /// @notice Set cliff period for staking
    /// @param _cliff New cliff duration in seconds
    function setCliff(uint256 _cliff) external onlyOwner {
        require(_cliff > 0, StakingConstants.ERROR_INVALID_CLIFF);
        cliff = _cliff;
        emit CliffUpdated(_cliff);
    }

    /// @notice Pause/unpause entire protocol
    /// @param _paused True to pause, false to resume
    function setProtocolPaused(bool _paused) external onlyOwner {
        paused = _paused;
        emit ProtocolPaused(_paused);
    }

    /// @notice Pause/unpause specific pool
    /// @param poolId Pool identifier
    /// @param state True to pause, false to resume
    function setPoolPaused(uint256 poolId, bool state) external onlyOwner {
        require(poolId > 0 && poolId <= poolCount, StakingConstants.ERROR_INVALID_POOL);
        poolPaused[poolId] = state;
        emit PoolPaused(poolId, state);
    }

    /// @notice Activate/deactivate pool
    /// @param poolId Pool identifier
    /// @param active True to activate, false to deactivate
    function setPoolStatus(uint256 poolId, bool active) external onlyOwner {
        require(poolId > 0 && poolId <= poolCount, StakingConstants.ERROR_INVALID_POOL);
        poolStatus[poolId] = active;
    }

    /// @notice Transfer protocol ownership
    /// @param newOwner Address of new owner
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), StakingConstants.ERROR_ZERO_ADDRESS);
        address previousOwner = owner;
        owner = newOwner;
        emit OwnershipTransferred(previousOwner, newOwner);
    }

    /// @notice Set reward strategy for a pool
    /// @param poolId Pool identifier
    /// @param strategy Address of reward strategy contract
    function setRewardStrategy(uint256 poolId, address strategy) external onlyOwner {
        require(poolId > 0 && poolId <= poolCount, StakingConstants.ERROR_INVALID_POOL);
        require(strategy != address(0), StakingConstants.ERROR_ZERO_ADDRESS);
        rewardStrategies[poolId] = strategy;
    }

    /// @notice Create a new staking pool
    /// @param stakingToken ERC20 token to stake
    /// @param rewardToken ERC20 reward token
    /// @param yieldPerSecond Reward yield per second
    function createPool(
        address stakingToken,
        address rewardToken,
        uint256 yieldPerSecond
    ) external onlyOwner {
        require(stakingToken != address(0), StakingConstants.ERROR_ZERO_ADDRESS);
        require(rewardToken != address(0), StakingConstants.ERROR_ZERO_ADDRESS);
        
        poolCount += 1;
        pools[poolCount] = PoolInfo(stakingToken, rewardToken, yieldPerSecond, 0);
        poolStatus[poolCount] = true;
        
        emit PoolCreated(poolCount, stakingToken, rewardToken, yieldPerSecond);
    }

    // =============================================================================
    // ERC20 STAKING FUNCTIONS
    // =============================================================================
    
    /// @notice Stake ERC20 tokens in a pool
    /// @param poolId Pool identifier
    /// @param amount Amount to stake
    function stakeToken(uint256 poolId, uint256 amount) external whenPoolActive(poolId) nonReentrant {
        require(amount > 0, StakingConstants.ERROR_INVALID_AMOUNT);
        
        PoolInfo storage _pool = pools[poolId];
        StakingInfo storage _info = stakes[_msgSender()][poolId];

        // Validate allowance and balance
        require(
            IERC20(_pool.stakingToken).allowance(_msgSender(), address(this)) >= amount,
            StakingConstants.ERROR_INSUFFICIENT_ALLOWANCE
        );
        require(
            IERC20(_pool.stakingToken).balanceOf(_msgSender()) >= amount,
            StakingConstants.ERROR_INSUFFICIENT_BALANCE
        );

        // Claim pending rewards if exists
        if (_info.stakeAmount > 0) {
            uint256 reward = fetchUnclaimedReward(poolId);
            if (reward > 0) {
                _safeTransfer(_pool.rewardToken, _msgSender(), reward);
            }
        }

        // Update staking info
        _info.stakeAmount += uint96(amount);
        _info.stakeTime = uint64(block.timestamp);
        _pool.totalStaked += amount;

        // Transfer tokens
        require(
            IERC20(_pool.stakingToken).transferFrom(_msgSender(), address(this), amount),
            StakingConstants.ERROR_TRANSFER_FAILED
        );
        
        emit Staked(_msgSender(), amount, poolId, block.timestamp);
    }

    /// @notice Claim rewards and optionally unstake
    /// @param poolId Pool identifier
    /// @param unStaking True to unstake, false to only claim rewards
    function claimRewards(uint256 poolId, bool unStaking) 
        external 
        whenPoolActive(poolId) 
        nonReentrant 
    {
        StakingInfo storage _info = stakes[_msgSender()][poolId];
        PoolInfo storage _pool = pools[poolId];
        
        require(_info.stakeAmount > 0, StakingConstants.ERROR_NO_STAKE);
        require(block.timestamp >= _info.stakeTime + cliff, StakingConstants.ERROR_CLIFF_NOT_PASSED);
        
        uint256 reward = fetchUnclaimedReward(poolId);
        require(reward > 0, StakingConstants.ERROR_NO_REWARD);

        if (unStaking) {
            uint256 amount = _info.stakeAmount;
            _pool.totalStaked -= amount;
            _info.stakeAmount = 0;
            
            require(
                IERC20(_pool.stakingToken).transfer(_msgSender(), amount),
                StakingConstants.ERROR_TRANSFER_FAILED
            );
        }

        _info.stakeTime = uint64(block.timestamp);
        _safeTransfer(_pool.rewardToken, _msgSender(), reward);
        
        emit Claimed(_msgSender(), reward, poolId, block.timestamp, unStaking);
    }

    /// @notice Emergency withdraw without claiming rewards
    /// @param poolId Pool identifier
    function emergencyWithdraw(uint256 poolId) external nonReentrant {
        StakingInfo storage _info = stakes[_msgSender()][poolId];
        PoolInfo storage _pool = pools[poolId];
        
        uint256 amount = _info.stakeAmount;
        require(amount > 0, StakingConstants.ERROR_NO_STAKE);
        
        _info.stakeAmount = 0;
        _pool.totalStaked -= amount;
        
        require(
            IERC20(_pool.stakingToken).transfer(_msgSender(), amount),
            StakingConstants.ERROR_TRANSFER_FAILED
        );
        
        emit EmergencyWithdraw(_msgSender(), poolId, amount, block.timestamp);
    }

    // =============================================================================
    // ERC721 STAKING FUNCTIONS
    // =============================================================================
    
    /// @notice Stake an NFT in a pool
    /// @param poolId Pool identifier
    /// @param nftAddress NFT contract address
    /// @param tokenId NFT token ID
    function stakeNFT(uint256 poolId, address nftAddress, uint256 tokenId) 
        external 
        whenPoolActive(poolId) 
        nonReentrant 
    {
        require(IERC721(nftAddress).ownerOf(tokenId) == _msgSender(), StakingConstants.ERROR_NOT_NFT_OWNER);
        require(nftAddress == nftContractPerPool[poolId], StakingConstants.ERROR_NFT_NOT_ALLOWED);

        NFTStakeInfo storage stakeRecord = nftStakes[_msgSender()][poolId][tokenId];
        require(stakeRecord.stakeTime == 0, StakingConstants.ERROR_NFT_ALREADY_STAKED);

        IERC721(nftAddress).transferFrom(_msgSender(), address(this), tokenId);
        nftStakes[_msgSender()][poolId][tokenId] = NFTStakeInfo(tokenId, block.timestamp);
        
        emit NFTStaked(_msgSender(), poolId, tokenId, block.timestamp);
    }

    /// @notice Unstake an NFT and claim rewards
    /// @param poolId Pool identifier
    /// @param nftAddress NFT contract address
    /// @param tokenId NFT token ID
    function unstakeNFT(uint256 poolId, address nftAddress, uint256 tokenId) 
        external 
        whenPoolActive(poolId) 
        nonReentrant 
    {
        NFTStakeInfo storage info = nftStakes[_msgSender()][poolId][tokenId];
        require(info.stakeTime != 0, StakingConstants.ERROR_NFT_NOT_STAKED);
        require(block.timestamp >= info.stakeTime + cliff, StakingConstants.ERROR_CLIFF_NOT_PASSED);

        uint256 reward = fetchUnclaimedNFTReward(poolId, tokenId);
        delete nftStakes[_msgSender()][poolId][tokenId];

        IERC721(nftAddress).transferFrom(address(this), _msgSender(), tokenId);

        if (reward > 0) {
            _safeTransfer(pools[poolId].rewardToken, _msgSender(), reward);
        }

        emit NFTUnstaked(_msgSender(), poolId, tokenId, block.timestamp);
    }

    // =============================================================================
    // VIEW FUNCTIONS
    // =============================================================================
    
    /// @notice Calculate unclaimed rewards for staked tokens
    /// @param poolId Pool identifier
    /// @return Unclaimed reward amount
    function fetchUnclaimedReward(uint256 poolId) public view returns (uint256) {
        StakingInfo storage _info = stakes[_msgSender()][poolId];
        address strategy = rewardStrategies[poolId];
        
        if (strategy != address(0) && _info.stakeAmount > 0) {
            return IRewardStrategy(strategy).calculateReward(
                _msgSender(),
                poolId,
                _info.stakeAmount,
                _info.stakeTime
            );
        }
        return 0;
    }

    /// @notice Calculate unclaimed rewards for staked NFT
    /// @param poolId Pool identifier
    /// @param tokenId NFT token ID
    /// @return Unclaimed reward amount
    function fetchUnclaimedNFTReward(uint256 poolId, uint256 tokenId) public view returns (uint256) {
        NFTStakeInfo storage info = nftStakes[_msgSender()][poolId][tokenId];
        PoolInfo storage _pool = pools[poolId];
        
        if (info.stakeTime == 0 || block.timestamp < info.stakeTime + cliff) {
            return 0;
        }
        
        uint256 duration = block.timestamp - info.stakeTime - cliff;
        return duration * _pool.yieldPerSecond;
    }

    /// @notice Get staking info for a user in a pool
    /// @param user User address
    /// @param poolId Pool identifier
    /// @return Staking info struct
    function getStakeInfo(address user, uint256 poolId) external view returns (StakingInfo memory) {
        return stakes[user][poolId];
    }

    /// @notice Get pool information
    /// @param poolId Pool identifier
    /// @return Pool info struct
    function getPoolInfo(uint256 poolId) external view returns (PoolInfo memory) {
        require(poolId > 0 && poolId <= poolCount, StakingConstants.ERROR_INVALID_POOL);
        return pools[poolId];
    }

    /// @notice Get reward strategy for a pool
    /// @param poolId Pool identifier
    /// @return Strategy contract address
    function getRewardStrategy(uint256 poolId) external view returns (address) {
        require(poolId > 0 && poolId <= poolCount, StakingConstants.ERROR_INVALID_POOL);
        return rewardStrategies[poolId];
    }

    // =============================================================================
    // INTERNAL FUNCTIONS
    // =============================================================================
    
    /// @notice Safe token transfer with error handling
    /// @param token Token address
    /// @param to Recipient address
    /// @param amount Transfer amount
    function _safeTransfer(address token, address to, uint256 amount) internal {
        require(
            IERC20(token).transfer(to, amount),
            StakingConstants.ERROR_TRANSFER_FAILED
        );
    }
}
