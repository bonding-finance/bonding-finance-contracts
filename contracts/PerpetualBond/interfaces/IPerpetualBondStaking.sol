// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/**
 * @title Perpetual bond staking interface
 * @author Bonding Finance
 */
interface IPerpetualBondStaking {
    event Stake(address indexed user, address indexed token, uint256 amount);
    event Unstake(address indexed user, address indexed token, uint256 amount);
    event EmergencyWithdraw(address indexed user, address indexed token, uint256 amount);
    event Claim(address indexed user, address indexed token, uint256 amount);
    event Distribute(
        address indexed pool,
        uint256 timestamp,
        uint256 rewardAmount,
        uint256 amountStaked
    );
    event CollectSurplus(address indexed feeTo, uint256 amount);

    struct PoolInfo {
        uint256 accRewardsPerShare;
        uint256 accRewards;
        uint256 claimedRewards;
    }

    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;
    }

    function factory() external view returns (address);

    function vault() external view returns (address);

    function yToken() external view returns (address);

    function lpToken() external view returns (address);

    function rewardToken() external view returns (address);

    function surplus() external view returns (uint256);

    function userInfo(
        address token,
        address user
    ) external view returns (uint256 amount, uint256 rewardDebt);

    function poolInfo(
        address token
    )
        external
        view
        returns (uint256 accRewardsPerShare, uint256 accRewards, uint256 claimedRewards);

    function stake(address token, uint256 amount) external returns (uint256 rewards);

    function unstake(address token, uint256 amount) external returns (uint256 rewards);

    function emergencyWithdraw(address token) external;

    function harvest() external;

    function pendingRewards(address token, address user) external view returns (uint256 rewards);

    //////////////////////////
    /* Restricted Functions */
    //////////////////////////

    function collectSurplus(address feeTo) external;
}
