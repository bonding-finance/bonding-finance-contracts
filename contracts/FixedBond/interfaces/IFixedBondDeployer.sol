// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

/**
 * @title Fixed-duration bond deployer interface
 * @author Bonding Finance
 */
interface IFixedBondDeployer {
    struct Parameters {
        address factory;
        address token;
        uint256 maturity;
    }

    function parameters() external view returns (address, address, uint256);
}
