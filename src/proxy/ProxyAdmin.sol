// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./StakingProxy.sol";
import "../libraries/StakingConstants.sol";

/// @title ProxyAdmin
/// @notice Admin contract for managing proxy upgrades
contract ProxyAdmin {
    address public owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event ProxyAdminChanged(address indexed proxy, address indexed newAdmin);

    modifier onlyOwner() {
        require(msg.sender == owner, StakingConstants.ERROR_NOT_OWNER);
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    /// @notice Upgrade proxy to new implementation
    /// @param proxyAddress Proxy contract address
    /// @param newImplementation New implementation address
    function upgrade(address payable proxyAddress, address newImplementation) external onlyOwner {
        require(proxyAddress != address(0), StakingConstants.ERROR_ZERO_ADDRESS);
        require(newImplementation != address(0), StakingConstants.ERROR_ZERO_ADDRESS);
        StakingProxy(proxyAddress).upgradeTo(newImplementation);
    }

    /// @notice Change proxy admin
    /// @param proxyAddress Proxy contract address
    /// @param newAdmin New admin address
    function changeProxyAdmin(address proxyAddress, address newAdmin) external onlyOwner {
        require(proxyAddress != address(0), StakingConstants.ERROR_ZERO_ADDRESS);
        require(newAdmin != address(0), StakingConstants.ERROR_ZERO_ADDRESS);
        StakingProxy(proxyAddress).changeAdmin(newAdmin);
        emit ProxyAdminChanged(proxyAddress, newAdmin);
    }

    /// @notice Transfer ownership of ProxyAdmin
    /// @param newOwner New owner address
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), StakingConstants.ERROR_ZERO_ADDRESS);
        address previousOwner = owner;
        owner = newOwner;
        emit OwnershipTransferred(previousOwner, newOwner);
    }
}
