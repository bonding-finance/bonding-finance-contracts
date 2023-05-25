// SPDX-License-Identifier: BUSL-1.1

pragma solidity >=0.8.0;

import "./interfaces/IBondToken.sol";
import "./BondTokenImpl.sol";

/**
 * @title Bond token contract
 * @author Bonding Finance
 */
contract BondToken is IBondToken, BondTokenImpl {
    address public immutable override vault;

    constructor(string memory _name, string memory _symbol, uint8 _decimals) {
        vault = msg.sender;
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
    }

    //////////////////////////
    /* Restricted Functions */
    //////////////////////////

    function mint(address user, uint256 amount) external override {
        _onlyVault();

        _mint(user, amount);
    }

    function burn(address user, uint256 amount) external override {
        _onlyVault();

        _burn(user, amount);
    }

    function _onlyVault() internal view {
        require(msg.sender == vault, "!vault");
    }
}
