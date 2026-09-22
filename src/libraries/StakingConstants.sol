// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title StakingConstants
/// @notice Centralized error messages and constants for the staking protocol
library StakingConstants {
    // =============================================================================
    // ERROR MESSAGES
    // =============================================================================
    
    string internal constant ERROR_NOT_OWNER = "StakingProtocol: Not owner";
    string internal constant ERROR_PROTOCOL_PAUSED = "StakingProtocol: Protocol paused";
    string internal constant ERROR_POOL_INACTIVE = "StakingProtocol: Pool inactive";
    string internal constant ERROR_POOL_PAUSED = "StakingProtocol: Pool paused";
    string internal constant ERROR_INVALID_POOL = "StakingProtocol: Invalid pool";
    string internal constant ERROR_ALREADY_INITIALIZED = "StakingProtocol: Already initialized";
    string internal constant ERROR_ZERO_ADDRESS = "StakingProtocol: Zero address";
    string internal constant ERROR_INVALID_CLIFF = "StakingProtocol: Invalid cliff";
    string internal constant ERROR_INVALID_AMOUNT = "StakingProtocol: Invalid amount";
    string internal constant ERROR_INSUFFICIENT_ALLOWANCE = "StakingProtocol: Insufficient allowance";
    string internal constant ERROR_INSUFFICIENT_BALANCE = "StakingProtocol: Insufficient balance";
    string internal constant ERROR_TRANSFER_FAILED = "StakingProtocol: Transfer failed";
    string internal constant ERROR_NO_STAKE = "StakingProtocol: No stake";
    string internal constant ERROR_CLIFF_NOT_PASSED = "StakingProtocol: Cliff not passed";
    string internal constant ERROR_NO_REWARD = "StakingProtocol: No reward";
    string internal constant ERROR_NOT_NFT_OWNER = "StakingProtocol: Not NFT owner";
    string internal constant ERROR_NFT_NOT_ALLOWED = "StakingProtocol: NFT not allowed in this pool";
    string internal constant ERROR_NFT_ALREADY_STAKED = "StakingProtocol: NFT already staked";
    string internal constant ERROR_NFT_NOT_STAKED = "StakingProtocol: NFT not staked";
    string internal constant ERROR_NO_IMPLEMENTATION = "StakingProtocol: No implementation";
    string internal constant ERROR_NOT_AUTHORIZED = "StakingProtocol: Not authorized";
}
