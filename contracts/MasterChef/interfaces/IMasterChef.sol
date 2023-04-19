// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/**
 * @title Bonding Finance master chef interface
 * @author Bonding Finance
 */
interface IMasterChef {
    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);

    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;
    }

    struct PoolInfo {
        address token;
        uint256 allocPoint;
        uint256 lastRewardBlock;
        uint256 accRewardsPerShare;
    }

    function esBND() external view returns (address);

    function startBlock() external view returns (uint256);

    function rewardPerBlock() external view returns (uint256);

    function totalAllocPoint() external view returns (uint256);

    function poolInfo(
        uint256
    )
        external
        view
        returns (
            address token,
            uint256 allocPoint,
            uint256 lastRewardBlock,
            uint256 accRewardsPerShare
        );

    function userInfo(
        uint256 pid,
        address user
    ) external view returns (uint256 amount, uint256 rewardDebt);

    function poolLength() external view returns (uint256);

    function pendingRewards(uint256 pid, address user) external view returns (uint256 rewards);

    function deposit(uint256 pid, uint256 amount) external;

    function withdraw(uint256 pid, uint256 amount) external;

    function emergencyWithdraw(uint256 pid) external;

    function massUpdatePools() external;

    function updatePool(uint256 pid) external;

    //////////////////////////
    /* Restricted Functions */
    //////////////////////////

    function add(uint256 allocPoint, address token, bool withUpdate) external;

    function set(uint256 pid, uint256 allocPoint, bool withUpdate) external;
}
