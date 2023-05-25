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
    uint256 public override fees;

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
     * @notice Stakes `amount` of `token`
     * @dev Harvests and claims rewards
     * @param token Token to stake
     * @param amount Amount of tokens to stake
     * @return rewards Amount of rewards claimed
     */
    function stake(
        address token,
        uint256 amount
    ) external override nonReentrant returns (uint256 rewards) {
        _validateToken(token);
        harvest();
        rewards = _claimRewards(token, msg.sender);

        UserInfo storage user = userInfo[token][msg.sender];
        if (amount != 0) {
            ERC20(token).safeTransferFrom(msg.sender, address(this), amount);
            user.amount += amount;
        }
        user.rewardDebt = (user.amount * poolInfo[token].accRewardsPerShare) / 1e18;

        emit Stake(msg.sender, token, amount);
    }

    /**
     * @notice Unstakes `amount` of `token`
     * @dev Harvests and claims rewards
     * @param token Token to unstake
     * @param amount Amount of tokens to unstake
     * @return rewards Amount of rewards claimed
     */
    function unstake(
        address token,
        uint256 amount
    ) external override nonReentrant returns (uint256 rewards) {
        _validateToken(token);
        harvest();
        rewards = _claimRewards(token, msg.sender);

        UserInfo storage user = userInfo[token][msg.sender];
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
        UserInfo storage user = userInfo[token][msg.sender];
        uint256 amount = user.amount;
        ERC20(token).safeTransfer(msg.sender, amount);

        user.amount = 0;
        user.rewardDebt = 0;

        emit EmergencyWithdraw(msg.sender, token, amount);
    }

    /**
     * @notice Calls `harvest()` on vault contract and then distributes pending rewards
     * @dev Rebase rewards from unclaimed rewards are also distributed
     */
    function harvest() public override {
        if (IPerpetualBondVault(vault).staking() == address(this)) {
            IPerpetualBondVault(vault).harvest();
        }

        // Accounts for rebase from unclaimed rewards
        uint256 balance = ERC20(rewardToken).balanceOf(address(this));
        uint256 rewards = balance + _totalClaimedRewards() - _totalAccRewards() - fees;
        _distribute(rewards);
    }

    /**
     * @notice Calculates `_user` pending rewards
     * @dev Does not include harvested rewards that have not been distributed yet
     * @param _token Address of the staked token
     * @param _user Address of the user
     * @return rewards Amount of pending rewards
     */
    function pendingRewards(
        address _token,
        address _user
    ) public view override returns (uint256 rewards) {
        UserInfo memory user = userInfo[_token][_user];
        rewards = ((user.amount * poolInfo[_token].accRewardsPerShare) / 1e18) - user.rewardDebt;
    }

    /**
     * @notice Claims all pending rewards for `user`
     * @param token Token to claim rewards for
     * @param user User to claim rewards for
     * @return rewards Amount of rewards claimed
     */
    function _claimRewards(address token, address user) internal returns (uint256 rewards) {
        if (userInfo[token][user].amount == 0) return 0;

        rewards = pendingRewards(token, user);
        if (rewards == 0) return 0;

        uint256 balance = ERC20(rewardToken).balanceOf(address(this));
        // In case of rounding error
        if (rewards > balance) rewards = balance;

        ERC20(rewardToken).safeTransfer(user, rewards);
        poolInfo[token].claimedRewards += rewards;

        emit Claim(user, token, rewards);
    }

    /**
     * @notice Distributes rewards to stakers
     * @param rewards Amount of rewards to distribute
     */
    function _distribute(uint256 rewards) internal {
        if (rewards == 0) return;

        uint256 yTokenStaked = ERC20(yToken).balanceOf(address(this));
        uint256 yTokenSupply = ERC20(yToken).totalSupply();

        // Forces yToken yield to match rebase yield, regardless of % staked
        uint256 yTokenRewards = yTokenSupply != 0 ? (rewards * yTokenStaked) / yTokenSupply : 0;
        uint256 miscRewards = rewards - yTokenRewards;

        // Distribute allocated rewards to yToken stakers
        if (yTokenRewards != 0) {
            PoolInfo storage yTokenPool = poolInfo[yToken];
            yTokenPool.accRewardsPerShare += (yTokenRewards * 1e18) / yTokenStaked;
            yTokenPool.accRewards += yTokenRewards;

            emit Distribute(yToken, block.timestamp, yTokenRewards, yTokenStaked);
        }

        // Distribute excess rewards to LP token stakers and protocol
        if (miscRewards != 0) {
            uint256 feeAmount = _chargeFee(miscRewards);
            uint256 lpRewards = miscRewards - feeAmount;
            if (lpRewards == 0) return;

            uint256 lpStaked = ERC20(lpToken).balanceOf(address(this));
            PoolInfo storage lpTokenPool = poolInfo[lpToken];
            lpTokenPool.accRewardsPerShare += (lpRewards * 1e18) / lpStaked;
            lpTokenPool.accRewards += lpRewards;

            emit Distribute(lpToken, block.timestamp, lpRewards, lpStaked);
        }
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
     * @notice Applies surplus fee (if any) to `amount`
     * @dev If LP token or staked amount is 0, all excess is distributed to the protocol
     * @param amount The original amount
     * @return feeAmount The fee amount charged
     */
    function _chargeFee(uint256 amount) internal returns (uint256 feeAmount) {
        if (lpToken == address(0) || ERC20(lpToken).balanceOf(address(this)) == 0) {
            feeAmount = amount;
        } else {
            (, , uint256 fee) = IPerpetualBondFactory(factory).feeInfo();
            if (fee == 0) return 0;

            feeAmount = (amount * fee) / 10000;
        }

        fees += feeAmount;

        emit Distribute(factory, block.timestamp, feeAmount, 0);
    }

    //////////////////////////
    /* Restricted Functions */
    //////////////////////////

    function collectFees(address feeTo) external override {
        require(msg.sender == factory, "!factory");

        if (fees == 0) return;

        ERC20(rewardToken).safeTransfer(feeTo, fees);

        emit CollectSurplus(feeTo, fees);

        delete fees;
    }
}
