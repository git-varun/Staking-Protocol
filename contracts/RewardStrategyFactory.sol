// SPDX License-Identifier: MIT
pragma solidity ^0.8.12;

import "./interfaces/IRewardStrategy.sol";
import "./strategies/LinearRewardStrategy.sol";
import "./strategies/FixedPerBlockStrategy.sol";
import "./strategies/NFTBoostedStrategy.sol";

// Factory Contract
contract RewardStrategyFactory {
    address public owner;
    mapping(uint256 => address) public poolStrategy;

    event StrategyDeployed(address strategy, uint256 poolId, string strategyType);
    event PoolStrategySet(uint256 indexed poolId, address strategy);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not authorized");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function deployLinearStrategy(uint256 poolId, uint256 yieldPerSecond) external onlyOwner returns (address) {
        LinearRewardStrategy strategy = new LinearRewardStrategy(yieldPerSecond);
        poolStrategy[poolId] = address(strategy);
        emit StrategyDeployed(address(strategy), poolId, "Linear");
        emit PoolStrategySet(poolId, address(strategy));
        return address(strategy);
    }

    function deployFixedPerBlockStrategy(uint256 poolId, uint256 fixedReward) external onlyOwner returns (address) {
        FixedPerBlockStrategy strategy = new FixedPerBlockStrategy(fixedReward);
        poolStrategy[poolId] = address(strategy);
        emit StrategyDeployed(address(strategy), poolId, "FixedPerBlock");
        emit PoolStrategySet(poolId, address(strategy));
        return address(strategy);
    }

    function deployNFTBoostedStrategy(uint256 poolId, uint256 baseYield, uint256 boostMultiplier) external onlyOwner returns (address) {
        NFTBoostedStrategy strategy = new NFTBoostedStrategy(baseYield, boostMultiplier);
        poolStrategy[poolId] = address(strategy);
        emit StrategyDeployed(address(strategy), poolId, "NFTBoosted");
        emit PoolStrategySet(poolId, address(strategy));
        return address(strategy);
    }

    function getStrategy(uint256 poolId) external view returns (address) {
        return poolStrategy[poolId];
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Zero address");
        owner = newOwner;
    }
}
