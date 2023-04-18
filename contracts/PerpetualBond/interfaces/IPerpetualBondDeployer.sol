// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/**
 * @title Perpetual bond deployer interface
 * @author Bonding Finance
 */
interface IPerpetualBondDeployer {
    struct Parameters {
        address factory;
        address token;
    }

    function parameters() external view returns (address, address);
}
