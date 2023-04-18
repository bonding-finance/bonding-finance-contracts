// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

import "./interfaces/IPerpetualBondToken.sol";
import "./PerpetualBondTokenImpl.sol";

/**
 * @title Perpetual bond token contract
 * @author Bonding Finance
 */
contract PerpetualBondToken is IPerpetualBondToken, PerpetualBondTokenImpl {
    address public immutable override vault;

    constructor(string memory _name, string memory _symbol, uint8 _decimals) {
        vault = msg.sender;
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
    }

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
