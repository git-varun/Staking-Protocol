// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

// Proxy Admin Contract
contract ProxyAdmin {
    address public owner;

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function upgrade(address proxyAddress, address newImplementation) external onlyOwner {
        StakingProxy(proxyAddress).upgradeTo(newImplementation);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid new owner");
        owner = newOwner;
    }
}
