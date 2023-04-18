// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "./interfaces/IBondingToken.sol";
import "../erc20/ERC20.sol";
import "./EscrowedBondingToken.sol";

/**
 * @title Bonding Finance DAO Token
 * @author Bonding Finance
 */
contract BondingToken is IBondingToken, ERC20 {
    address public immutable override esBND;

    constructor() ERC20("Bonding Finance Token", "BND", 18) {
        esBND = msg.sender;
    }

    //////////////////////////
    /* Restricted Functions */
    //////////////////////////

    function mint(address user, uint256 amount) external override {
        require(msg.sender == esBND, "!esBND");
        _mint(user, amount);
    }
}
