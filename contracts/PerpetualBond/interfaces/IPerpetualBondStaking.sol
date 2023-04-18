// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

interface IPerpetualBondStaking {
    event Stake(address indexed user, uint256 amount);
    event Unstake(address indexed user, uint256 amount);
    event Claim(address indexed user, uint256 amount);
    event Distribute(uint256 amount, uint256 accRewardsPerShare);

    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;
    }

    function vault() external view returns (address);

    function yToken() external view returns (address);

    function reward() external view returns (address);

    function accRewardsPerShare() external view returns (uint256);

    function accRewards() external view returns (uint256);

    function claimedRewards() external view returns (uint256);

    function userInfo(address user) external view returns (uint256 amount, uint256 rewardDebt);

    function pendingRewards(address user) external view returns (uint256 amount);

    function stake(uint256 amount) external;

    function unstake(uint256 amount) external;

    function distribute() external;
}
