// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/**
 * @title Bonding Finance DAO token interface
 * @author Bonding Finance
 */
interface IBondingToken {
    function esBND() external view returns (address);

    function mint(address user, uint256 amount) external;
}
