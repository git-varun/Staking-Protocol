// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

contract StakingProxy {
    constructor(address _impl) {
        _setImplementation(_impl);
        _setAdmin(msg.sender);
    }

    function upgradeTo(address newImplementation) external {
        require(msg.sender == _admin(), "Only admin");
        _setImplementation(newImplementation);
    }

    // EIP-1967 implementation slot: bytes32(uint256(keccak256('eip1967.proxy.implementation')) - 1)
    function _implementation() internal view returns (address impl) {
        bytes32 slot = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
        assembly { impl := sload(slot) }
    }
    function _setImplementation(address impl) internal {
        bytes32 slot = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
        assembly { sstore(slot, impl) }
    }

    // EIP-1967 admin slot: bytes32(uint256(keccak256('eip1967.proxy.admin')) - 1)
    function _admin() internal view returns (address adm) {
        bytes32 slot = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;
        assembly { adm := sload(slot) }
    }
    function _setAdmin(address adm) internal {
        bytes32 slot = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;
        assembly { sstore(slot, adm) }
    }

    fallback() external payable {
        address impl = _implementation();
        require(impl != address(0), "No implementation");
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), impl, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }

    receive() external payable {}
}