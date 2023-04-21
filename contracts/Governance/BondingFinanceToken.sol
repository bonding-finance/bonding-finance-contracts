// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "../erc20/ERC20.sol";

/**
 * @title Bonding Finance DAO Token
 * @author Bonding Finance
 */
contract BondingFinanceToken is ERC20 {
    constructor() ERC20("Bonding Finance DAO Token", "BND", 18) {
        _mint(msg.sender, 1_000_000 ether);
    }
}
