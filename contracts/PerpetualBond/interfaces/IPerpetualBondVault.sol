// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/**
 * @title Perpetual bond vault interface
 * @author Bonding Finance
 */
interface IPerpetualBondVault {
    event Mint(address indexed user, uint256 amount);
    event Redeem(address indexed user, uint256 amount);
    event Harvest(uint256 amount);
    event CollectFees(address indexed feeTo, uint256 amount);

    function factory() external view returns (address);

    function token() external view returns (address);

    function dToken() external view returns (address);

    function yToken() external view returns (address);

    function staking() external view returns (address);

    function totalDeposits() external view returns (uint256);

    function fees() external view returns (uint256);

    function deposit(uint256 amount) external returns (uint256 mintAmount);

    function redeem(uint256 amount) external returns (uint256 redeemAmount);

    function harvest() external;

    function pendingRewards() external view returns (uint256);

    //////////////////////////
    /* Restricted Functions */
    //////////////////////////

    function setStaking(address staking) external;

    function collectFees(address feeTo) external;
}
