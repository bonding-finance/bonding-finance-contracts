// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "../erc20/ERC20.sol";

contract LpToken is ERC20 {
    constructor(uint256 amount) ERC20("LP", "LP", 18) {
        _mint(msg.sender, amount);
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
