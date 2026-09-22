// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../libraries/StakingConstants.sol";

/// @title StakingProxy
/// @notice EIP-1967 compliant transparent proxy for upgradeable staking contract
contract StakingProxy {
    // EIP-1967 implementation slot
    bytes32 internal constant IMPLEMENTATION_SLOT =
        0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
    
    // EIP-1967 admin slot
    bytes32 internal constant ADMIN_SLOT =
        0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

    event Upgraded(address indexed implementation);
    event AdminChanged(address indexed previousAdmin, address indexed newAdmin);

    /// @notice Initialize proxy with implementation address
    /// @param _impl Initial implementation address
    constructor(address _impl) {
        require(_impl != address(0), StakingConstants.ERROR_ZERO_ADDRESS);
        _setImplementation(_impl);
        _setAdmin(msg.sender);
        emit Upgraded(_impl);
    }

    /// @notice Upgrade to new implementation (admin only)
    /// @param newImplementation New implementation address
    function upgradeTo(address newImplementation) external {
        require(msg.sender == _admin(), StakingConstants.ERROR_NOT_OWNER);
        require(newImplementation != address(0), StakingConstants.ERROR_ZERO_ADDRESS);
        _setImplementation(newImplementation);
        emit Upgraded(newImplementation);
    }

    /// @notice Change proxy admin
    /// @param newAdmin New admin address
    function changeAdmin(address newAdmin) external {
        require(msg.sender == _admin(), StakingConstants.ERROR_NOT_OWNER);
        require(newAdmin != address(0), StakingConstants.ERROR_ZERO_ADDRESS);
        address previousAdmin = _admin();
        _setAdmin(newAdmin);
        emit AdminChanged(previousAdmin, newAdmin);
    }

    /// @notice Get current implementation address
    /// @return Current implementation address
    function implementation() external view returns (address) {
        return _implementation();
    }

    /// @notice Get current admin address
    /// @return Current admin address
    function admin() external view returns (address) {
        return _admin();
    }

    /// @notice Internal function to get implementation from storage
    function _implementation() internal view returns (address impl) {
        assembly {
            impl := sload(IMPLEMENTATION_SLOT)
        }
    }

    /// @notice Internal function to set implementation in storage
    function _setImplementation(address impl) internal {
        assembly {
            sstore(IMPLEMENTATION_SLOT, impl)
        }
    }

    /// @notice Internal function to get admin from storage
    function _admin() internal view returns (address adm) {
        assembly {
            adm := sload(ADMIN_SLOT)
        }
    }

    /// @notice Internal function to set admin in storage
    function _setAdmin(address adm) internal {
        assembly {
            sstore(ADMIN_SLOT, adm)
        }
    }

    /// @notice Delegate calls to implementation
    fallback() external payable {
        address impl = _implementation();
        require(impl != address(0), StakingConstants.ERROR_NO_IMPLEMENTATION);
        
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), impl, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }

    receive() external payable {}
}
