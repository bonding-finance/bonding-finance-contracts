// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "./interfaces/IFixedBondDeployer.sol";
import "./FixedBondVault.sol";

/**
 * @title Fixed-duration bond deployer contract
 * @author Bonding Finance
 */
contract FixedBondDeployer is IFixedBondDeployer {
    Parameters public override parameters;

    /**
     * @notice Deploys vault contract
     * @param factory Factory address
     * @param token Underlying token of the vault
     * @param maturity Timestamp of bond maturity
     */
    function deploy(
        address factory,
        address token,
        uint256 maturity
    ) internal returns (address vault) {
        parameters = Parameters({factory: factory, token: token, maturity: maturity});
        vault = address(new FixedBondVault{salt: keccak256(abi.encode(token))}());
        delete parameters;
    }
}
