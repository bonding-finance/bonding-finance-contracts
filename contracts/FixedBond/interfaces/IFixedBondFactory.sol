// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

/**
 * @title Fixed-duration bond factory interface
 * @author Bonding Finance
 */
interface IFixedBondFactory {
    event VaultCreated(address indexed token, uint256 indexed maturity, address vault);

    struct FeeInfo {
        address feeTo;
        uint256 vaultFee;
        uint256 surplusFee;
    }

    function paused() external view returns (bool);

    function feeInfo() external view returns (address feeTo, uint256 vaultFee, uint256 surplusFee);

    function allVaults(uint256) external view returns (address);

    function getVault(address token, uint256 maturity) external view returns (address);

    function allVaultsLength() external view returns (uint256);

    //////////////////////////
    /* Restricted Functions */
    //////////////////////////

    function createVault(address token, uint256 maturity) external returns (address vault);

    function setPaused(bool paused) external;

    function setStaking(address vault, address staking) external;

    function collectVaultFees(address vault) external;

    function collectSurplusFees(address staking) external;

    function setFeeTo(address feeTo) external;

    function setVaultFee(uint256 vaultFee) external;

    function setSurplusFee(uint256 surplusFee) external;
}
