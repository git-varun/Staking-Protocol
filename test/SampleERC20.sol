// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract SampleERC20 is ERC20 {
    constructor() ERC20("SampleToken", "SMP") {
        _mint(msg.sender, 1_000_000 ether);
    }

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}