// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "./interfaces/IPerpetualBondDeployer.sol";
import "./PerpetualBondVault.sol";

/**
 * @title Bonding Finance bond deployer contract
 * @author Bonding Finance
 */
contract PerpetualBondDeployer is IPerpetualBondDeployer {
    Parameters public override parameters;

    /**
     * @notice Deploys bond contract
     * @param factory Factory address
     * @param token Underlying token of the bond
     */
    function deploy(address factory, address token) internal returns (address vault) {
        parameters = Parameters({factory: factory, token: token});
        vault = address(new PerpetualBondVault{salt: keccak256(abi.encode(token))}());
        delete parameters;
    }
}
