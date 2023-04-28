// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./interfaces/IPerpetualBondFactory.sol";
import "./PerpetualBondDeployer.sol";
import "../utils/Owned.sol";

/**
 * @title Perpetual bond factory contract
 * @author Bonding Finance
 */
contract PerpetualBondFactory is IPerpetualBondFactory, PerpetualBondDeployer, Owned {
    FeeInfo public override feeInfo;
    address[] public override allVaults;

    mapping(address => address) public override getVault;

    function allVaultsLength() external view override returns (uint256) {
        return allVaults.length;
    }

    //////////////////////////
    /* Restricted Functions */
    //////////////////////////

    /**
     * @notice Creates the perpetual bond vault contract
     * @dev Deploys vault, dToken, and yToken contracts
     * @param token Underlying token of the vault
     * @return vault Address of the created vault
     */
    function createVault(address token) external override onlyOwner returns (address vault) {
        require(token != address(0));
        require(getVault[token] == address(0), "Vault exists");

        vault = deploy(address(this), token);
        getVault[token] = vault;
        allVaults.push(vault);

        emit VaultCreated(token, vault);
    }

    function setStaking(address vault, address staking) external override onlyOwner {
        require(staking != address(0));
        require(IPerpetualBondStaking(staking).vault() == vault, "!valid");

        IPerpetualBondVault(vault).setStaking(staking);
    }

    function collectFees(address vault) external override onlyOwner {
        require(vault != address(0));
        require(feeInfo.feeTo != address(0), "feeTo is 0");

        IPerpetualBondVault(vault).collectFees(feeInfo.feeTo);
    }

    function collectSurplus(address staking) external override onlyOwner {
        require(staking != address(0));
        require(feeInfo.feeTo != address(0), "feeTo is 0");

        IPerpetualBondStaking(staking).collectSurplus(feeInfo.feeTo);
    }

    function setFeeTo(address feeTo) external override onlyOwner {
        feeInfo.feeTo = feeTo;
    }

    function setVaultFee(uint256 vaultFee) external override onlyOwner {
        require(vaultFee <= 100, "Fee > 100");

        feeInfo.vaultFee = vaultFee;
    }

    function setSurplusFee(uint256 surplusFee) external override onlyOwner {
        require(surplusFee <= 10000, "Fee > 10000");

        feeInfo.surplusFee = surplusFee;
    }
}
