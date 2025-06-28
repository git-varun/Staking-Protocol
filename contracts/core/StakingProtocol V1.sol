// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "./IStakingProtocol.sol";

contract StakingProtocol is Context, IStakingProtocol {
    address public owner;
    uint256 public poolCount;
    uint256 public cliff;
    bool public paused;

    mapping(uint256 => PoolInfo) public pool;
    mapping(address => mapping(uint256 => StakingInfo)) public stake;
    mapping(uint256 => bool) public poolStatus;
    mapping(uint256 => bool) public poolPaused;
    mapping(uint256 => address) public nftContractPerPool;
    mapping(address => mapping(uint256 => mapping(uint256 => NFTStakeInfo))) public nftStake;
    mapping(uint256 => address) public rewardStrategy;

    // Reserved storage space for upgradeability
    uint256[50] private __gap;

    // Events
    event OwnershipTransferred(address indexed oldOwner, address indexed newOwner);
    event Initialized(address indexed by, uint256 at);
    event NFTStaked(address indexed user, uint256 indexed poolId, uint256 tokenId, uint256 time);
    event NFTUnstaked(address indexed user, uint256 indexed poolId, uint256 tokenId, uint256 time);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier whenPoolActive(uint256 poolId) {
        require(!paused, "Protocol paused");
        require(poolStatus[poolId], "Inactive pool");
        require(!poolPaused[poolId], "Pool paused");
        _;
    }

    // Initializer
    bool private _initialized;
    function initialize(address _owner, uint256 _cliff) external {
        require(!_initialized, "Already initialized");
        owner = _owner;
        cliff = _cliff;
        poolCount = 0;
        paused = false;
        _initialized = true;
        emit OwnershipTransferred(address(0), _owner);
        emit Initialized(_owner, block.timestamp);
    }

    function setCliff(uint256 _cliff) external onlyOwner {
        cliff = _cliff;
    }

    function changeStakingStatus(bool _paused) external onlyOwner {
        paused = _paused;
    }

    function pausePool(uint256 poolId, bool state) external onlyOwner {
        require(poolId > 0 && poolId <= poolCount, "Invalid pool");
        poolPaused[poolId] = state;
    }

    function changePoolStatus(uint256 poolId, bool active) external onlyOwner {
        require(poolId > 0 && poolId <= poolCount, "Invalid pool");
        poolStatus[poolId] = active;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function setRewardStrategy(uint256 poolId, address strategy) external onlyOwner {
        require(poolId > 0 && poolId <= poolCount, "Invalid pool");
        rewardStrategy[poolId] = strategy;
    }

    function createPool(address stakingToken, address rewardToken, uint256 yieldPerSecond) external onlyOwner {
        require(stakingToken != address(0) && rewardToken != address(0), "Zero address");
        poolCount += 1;
        pool[poolCount] = PoolInfo(stakingToken, rewardToken, yieldPerSecond, 0);
        poolStatus[poolCount] = true;
        emit PoolCreated(poolCount, stakingToken, rewardToken, yieldPerSecond);
    }

    function stakeToken(uint256 poolId, uint256 amount) external whenPoolActive(poolId) {
        PoolInfo storage _pool = pool[poolId];
        StakingInfo storage _info = stake[_msgSender()][poolId];

        require(IERC20(_pool.stakingToken).allowance(_msgSender(), address(this)) >= amount, "Insufficient allowance");
        require(IERC20(_pool.stakingToken).balanceOf(_msgSender()) >= amount, "Insufficient balance");

        if (_info.stakeAmount > 0) {
            uint256 reward = fetchUnclaimedReward(poolId);
            if (reward > 0) {
                require(IERC20(_pool.rewardToken).transfer(_msgSender(), reward), "Reward transfer failed");
            }
        }

        _info.stakeAmount += amount;
        _info.stakeTime = block.timestamp;
        _pool.totalStaked += amount;
        require(IERC20(_pool.stakingToken).transferFrom(_msgSender(), address(this), amount), "Stake transfer failed");
        emit Staked(_msgSender(), amount, poolId, block.timestamp);
    }

    function claimToken(uint256 poolId, bool unStaking) external whenPoolActive(poolId) {
        StakingInfo storage _info = stake[_msgSender()][poolId];
        PoolInfo storage _pool = pool[poolId];
        require(_info.stakeAmount > 0, "Nothing staked");
        require(block.timestamp >= _info.stakeTime + cliff, "Cliff not passed");
        uint256 reward = fetchUnclaimedReward(poolId);
        require(reward > 0, "No reward");

        if (unStaking) {
            uint256 amount = _info.stakeAmount;
            _pool.totalStaked -= amount;
            _info.stakeAmount = 0;
            require(IERC20(_pool.stakingToken).transfer(_msgSender(), amount), "Unstake transfer failed");
        }

        _info.stakeTime = block.timestamp;
        require(IERC20(_pool.rewardToken).transfer(_msgSender(), reward), "Reward transfer failed");
        emit Claimed(_msgSender(), reward, poolId, block.timestamp, unStaking);
    }

    function emergencyWithdraw(uint256 poolId) external {
        StakingInfo storage _info = stake[_msgSender()][poolId];
        PoolInfo storage _pool = pool[poolId];
        uint256 amount = _info.stakeAmount;
        require(amount > 0, "Nothing to withdraw");
        _info.stakeAmount = 0;
        _pool.totalStaked -= amount;
        require(IERC20(_pool.stakingToken).transfer(_msgSender(), amount), "Emergency withdraw failed");
        emit EmergencyWithdraw(_msgSender(), poolId, amount, block.timestamp);
    }

    function fetchUnclaimedReward(uint256 poolId) public view returns (uint256) {
        StakingInfo storage _info = stake[_msgSender()][poolId];
        if (rewardStrategy[poolId] != address(0)) {
            return IRewardStrategy(rewardStrategy[poolId]).calculateReward(_msgSender(), poolId, _info.stakeAmount, _info.stakeTime);
        }
        return 0;
    }

    function stakeInfo(address user, uint256 poolId) external view returns (StakingInfo memory) {
        if (block.timestamp >= stake[user][poolId].stakeTime + cliff) {
            return stake[user][poolId];
        } else {
            return stake[address(0)][0];
        }
    }

    function fetchPoolInfo(uint256 poolId) external view returns (PoolInfo memory) {
        return pool[poolId];
    }

    function stakeNFT(uint256 poolId, address nftAddress, uint256 tokenId) external whenPoolActive(poolId) {
        require(IERC721(nftAddress).ownerOf(tokenId) == _msgSender(), "Not NFT owner");
        require(nftAddress == nftContractPerPool[poolId], "NFT not allowed in this pool");

        NFTStakeInfo storage stakeRecord = nftStake[_msgSender()][poolId][tokenId];
        require(stakeRecord.stakeTime == 0, "Already staked");

        IERC721(nftAddress).transferFrom(_msgSender(), address(this), tokenId);
        nftStake[_msgSender()][poolId][tokenId] = NFTStakeInfo(tokenId, block.timestamp);
        emit NFTStaked(_msgSender(), poolId, tokenId, block.timestamp);
    }

    function unstakeNFT(uint256 poolId, address nftAddress, uint256 tokenId) external whenPoolActive(poolId) {
        NFTStakeInfo storage info = nftStake[_msgSender()][poolId][tokenId];
        require(info.stakeTime != 0, "NFT not staked");
        require(block.timestamp >= info.stakeTime + cliff, "Cliff not passed");

        uint256 reward = fetchUnclaimedNFTReward(poolId, tokenId);
        delete nftStake[_msgSender()][poolId][tokenId];

        require(IERC721(nftAddress).transferFrom(address(this), _msgSender(), tokenId), "NFT return failed");

        if (reward > 0) {
            require(IERC20(pool[poolId].rewardToken).transfer(_msgSender(), reward), "Reward transfer failed");
        }

        emit NFTUnstaked(_msgSender(), poolId, tokenId, block.timestamp);
    }

    function fetchUnclaimedNFTReward(uint256 poolId, uint256 tokenId) public view returns (uint256) {
        NFTStakeInfo storage info = nftStake[_msgSender()][poolId][tokenId];
        PoolInfo storage _pool = pool[poolId];
        if (info.stakeTime == 0 || block.timestamp < info.stakeTime + cliff) return 0;
        uint256 duration = block.timestamp - info.stakeTime - cliff;
        uint256 reward = duration * _pool.yieldPerSecond;
        return reward;
    }
}
// Interface for reward strategy