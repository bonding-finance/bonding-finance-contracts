// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./interfaces/IPerpetualBondStaking.sol";
import "./interfaces/IPerpetualBondVault.sol";
import "./interfaces/IPerpetualBondFactory.sol";
import "../erc20/ERC20.sol";
import "../erc20/SafeERC20.sol";
import "../utils/ReentrancyGuard.sol";

/**
 * @title Perpetual bond staking contract
 * @author Bonding Finance
 */
contract PerpetualBondStaking is IPerpetualBondStaking, ReentrancyGuard {
    using SafeERC20 for ERC20;

    address public immutable override factory;
    address public immutable override vault;
    address public immutable override yToken;
    address public immutable override lpToken;
    address public immutable override rewardToken;
    uint256 public override surplus;

    mapping(address => mapping(address => UserInfo)) public override userInfo;
    mapping(address => PoolInfo) public override poolInfo;

    constructor(address _vault, address _lpToken) {
        require(_vault != address(0));
        factory = IPerpetualBondVault(_vault).factory();
        vault = _vault;
        yToken = IPerpetualBondVault(_vault).yToken();
        // Note: If _lpToken is 0, the protocol will earn all surplus yield
        lpToken = _lpToken;
        rewardToken = IPerpetualBondVault(_vault).token();
    }

    /**
     * @notice Calculates `_user` pending rewards
     * @param _user Address of the user
     * @param _token Address of the staked token
     * @return rewards Amount of pending rewards for `_user`
     */
    function pendingRewards(
        address _user,
        address _token
    ) public view override returns (uint256 rewards) {
        UserInfo memory user = userInfo[_user][_token];
        rewards = ((user.amount * poolInfo[_token].accRewardsPerShare) / 1e18) - user.rewardDebt;
    }

    /**
     * @notice Stakes `amount` of `token`
     * @dev Harvests and claims rewards
     * @param token Token to stake
     * @param amount Amount of tokens to stake
     */
    function stake(address token, uint256 amount) external override nonReentrant {
        _validateToken(token);
        _harvestRewards();
        _claimRewards(msg.sender, token);

        UserInfo storage user = userInfo[msg.sender][token];
        if (amount != 0) {
            ERC20(token).safeTransferFrom(msg.sender, address(this), amount);
            user.amount += amount;
        }
        user.rewardDebt = (user.amount * poolInfo[token].accRewardsPerShare) / 1e18;

        emit Stake(msg.sender, token, amount);
    }

    /**
     * @notice Unstakes `amount` of `token`
     * @notice Harvests and claims rewards
     * @notice token Token to unstake
     * @param token Token to unstake
     * @param amount Amount of tokens to unstake
     */
    function unstake(address token, uint256 amount) external override nonReentrant {
        _validateToken(token);
        _harvestRewards();
        _claimRewards(msg.sender, token);

        UserInfo storage user = userInfo[msg.sender][token];
        user.amount -= amount;
        user.rewardDebt = (user.amount * poolInfo[token].accRewardsPerShare) / 1e18;
        ERC20(token).safeTransfer(msg.sender, amount);

        emit Unstake(msg.sender, token, amount);
    }

    /**
     * @notice Emergency withdraw `token`
     * @dev Does not claim rewards
     * @param token Token to withdraw
     */
    function emergencyWithdraw(address token) external override nonReentrant {
        UserInfo storage user = userInfo[msg.sender][token];
        uint256 amount = user.amount;
        ERC20(token).safeTransfer(msg.sender, amount);

        user.amount = 0;
        user.rewardDebt = 0;

        emit Unstake(msg.sender, token, amount);
    }

    /**
     * @notice Calculates the total amount of rewards accrued
     * @return totalRewards Total rewards accrued
     */
    function _totalAccRewards() internal view returns (uint256 totalRewards) {
        totalRewards = poolInfo[yToken].accRewards + poolInfo[lpToken].accRewards;
    }

    /**
     * @notice Calculates the total amount of claimed rewards
     * @return totalClaimed Total rewards claimed
     */
    function _totalClaimedRewards() internal view returns (uint256 totalClaimed) {
        totalClaimed = poolInfo[yToken].claimedRewards + poolInfo[lpToken].claimedRewards;
    }

    /**
     * @notice Validates `token` is a supported token
     * @param token Token to validate
     */
    function _validateToken(address token) internal view {
        require(token != address(0) && (token == yToken || token == lpToken), "!valid");
    }

    /**
     * @notice Calls `harvest()` on vault contract
     */
    function _harvestRewards() internal {
        IPerpetualBondVault(vault).harvest();
    }

    /**
     * @notice Claims all pending rewards for `user`
     * @param user User to claim rewards for
     * @param token Token to claim rewards for
     */
    function _claimRewards(address user, address token) internal {
        if (userInfo[user][token].amount == 0) return;

        uint256 rewards = pendingRewards(user, token);
        if (rewards == 0) return;

        uint256 balance = ERC20(rewardToken).balanceOf(address(this));
        // In case of rounding error
        if (rewards > balance) rewards = balance;

        ERC20(rewardToken).safeTransfer(user, rewards);
        poolInfo[token].claimedRewards += rewards;

        emit Claim(user, token, rewards);
    }

    //////////////////////////
    /* Restricted Functions */
    //////////////////////////

    /**
     * @notice Distributes rebase rewards from vault to stakers
     * @dev Rebase rewards from unclaimed rewards are redistributed
     */
    function distribute() external override {
        require(msg.sender == vault, "!vault");

        uint256 balance = ERC20(rewardToken).balanceOf(address(this));
        uint256 rewardAmount = balance + _totalClaimedRewards() - _totalAccRewards() - surplus;

        uint256 yTokenStaked = ERC20(yToken).balanceOf(address(this));
        uint256 yTokenSupply = ERC20(yToken).totalSupply();

        uint256 amountToBondStakers = yTokenSupply != 0
            ? (rewardAmount * yTokenStaked) / yTokenSupply
            : 0;
        uint256 amountToOthers = rewardAmount - amountToBondStakers;

        // Distribute pro-rata share of rewards to yToken stakers
        if (amountToBondStakers != 0) {
            PoolInfo storage yTokenPool = poolInfo[yToken];
            yTokenPool.accRewardsPerShare += (amountToBondStakers * 1e18) / yTokenStaked;
            yTokenPool.accRewards += amountToBondStakers;

            emit Distribute(yToken, amountToBondStakers);
        }

        // If `lpToken` is not set or 0 staked LP tokens, all excess rewards go to the protocol
        // Otherwise, all excess rewards go to LP token stakers
        if (amountToOthers != 0) {
            if (lpToken == address(0) || ERC20(lpToken).balanceOf(address(this)) == 0) {
                surplus += amountToOthers;

                emit Distribute(factory, amountToOthers);
            } else {
                uint256 totalLpStaked = ERC20(lpToken).balanceOf(address(this));
                PoolInfo storage lpTokenPool = poolInfo[lpToken];
                lpTokenPool.accRewardsPerShare += (amountToOthers * 1e18) / totalLpStaked;
                lpTokenPool.accRewards += amountToOthers;

                emit Distribute(lpToken, amountToOthers);
            }
        }
    }

    /**
     * @notice Collects surplus yield
     * @param feeTo Address to send surplus to
     */
    function collectSurplus(address feeTo) external override {
        require(msg.sender == factory, "!factory");

        if (surplus == 0) return;

        ERC20(rewardToken).safeTransfer(feeTo, surplus);
        delete surplus;
    }
}
