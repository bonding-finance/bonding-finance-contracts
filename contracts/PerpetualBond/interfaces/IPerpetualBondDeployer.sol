// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

interface IPerpetualBondDeployer {
    struct Parameters {
        address factory;
        address token;
    }

    function parameters() external view returns (address, address);
}
