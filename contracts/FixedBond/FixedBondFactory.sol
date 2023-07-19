// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "./interfaces/IFixedBondFactory.sol";
import "./FixedBondDeployer.sol";
import "../utils/Owned.sol";

/**
 * @title Fixed-duration bond factory contract
 * @author Bonding Finance
 */
contract FixedBondFactory is IFixedBondFactory, FixedBondDeployer, Owned {
    bool public override paused;
    FeeInfo public override feeInfo;
    address[] public override allVaults;

    mapping(address => mapping(uint256 => address)) public override getVault;

    function allVaultsLength() external view override returns (uint256) {
        return allVaults.length;
    }

    //////////////////////////
    /* Restricted Functions */
    //////////////////////////

    /**
     * @notice Creates the fixed-duration bond vault contract
     * @dev Deploys vault, dToken, and yToken contracts
     * @param token Underlying token of the vault
     * @param maturity Timestamp of bond maturity
     * @return vault Address of the created vault
     */
    function createVault(
        address token,
        uint256 maturity
    ) external override onlyOwner returns (address vault) {
        require(token != address(0));
        require(getVault[token][maturity] == address(0), "Vault exists");

        vault = deploy(address(this), token, maturity);
        getVault[token][maturity] = vault;
        allVaults.push(vault);

        emit VaultCreated(token, maturity, vault);
    }

    function setPaused(bool _paused) external override onlyOwner {
        paused = _paused;
    }

    function setStaking(address vault, address staking) external override onlyOwner {
        require(vault != address(0));
        require(staking != address(0));
        require(IFixedBondStaking(staking).vault() == vault, "!valid");

        IFixedBondVault(vault).setStaking(staking);
    }

    function collectVaultFees(address vault) external override onlyOwner {
        require(vault != address(0));
        require(feeInfo.feeTo != address(0), "feeTo is 0");

        IFixedBondVault(vault).collectFees(feeInfo.feeTo);
    }

    function collectSurplusFees(address staking) external override onlyOwner {
        require(staking != address(0));
        require(feeInfo.feeTo != address(0), "feeTo is 0");

        IFixedBondStaking(staking).collectFees(feeInfo.feeTo);
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
