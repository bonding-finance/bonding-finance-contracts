// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./interfaces/IPerpetualBondStaking.sol";
import "./interfaces/IPerpetualBondVault.sol";
import "../erc20/ERC20.sol";
import "../erc20/SafeERC20.sol";
import "../utils/ReentrancyGuard.sol";

/**
 * @title Perpetual bond (yToken) staking contract
 * @author Bonding Finance
 */
contract PerpetualBondStaking is IPerpetualBondStaking, ReentrancyGuard {
    using SafeERC20 for ERC20;

    address public immutable override vault;
    address public immutable override yToken;
    address public immutable override reward;
    uint256 public override accRewardsPerShare;
    uint256 public override accRewards;
    uint256 public override claimedRewards;

    mapping(address => UserInfo) public override userInfo;

    constructor(address _yToken, address _reward) {
        vault = msg.sender;
        yToken = _yToken;
        reward = _reward;
    }

    /**
     * @notice Calculates pending rewards for `_user`
     * @param _user Address of the user
     * @return amount Amount of pending rewards for `_user`
     */
    function pendingRewards(address _user) public view override returns (uint256 amount) {
        UserInfo memory user = userInfo[_user];
        amount = ((user.amount * accRewardsPerShare) / 1e18) - user.rewardDebt;
    }

    /**
     * @notice Stakes `amount` yTokens for rewards
     * @dev Harvests and claims rewards
     * @param amount Amount of yTokens to stake
     */
    function stake(uint256 amount) external override nonReentrant {
        _harvestRewards();
        _claimRewards(msg.sender);

        UserInfo storage user = userInfo[msg.sender];
        if (amount != 0) {
            ERC20(yToken).safeTransferFrom(msg.sender, address(this), amount);
            user.amount += amount;
        }
        user.rewardDebt = (user.amount * accRewardsPerShare) / 1e18;

        emit Stake(msg.sender, amount);
    }

    /**
     * @notice Unstakes `amount` of yTokens
     * @notice Harvests and claims rewards
     * @param amount Amount of yTokens to unstake
     */
    function unstake(uint256 amount) external override nonReentrant {
        _harvestRewards();
        _claimRewards(msg.sender);

        UserInfo storage user = userInfo[msg.sender];
        user.amount -= amount;
        user.rewardDebt = (user.amount * accRewardsPerShare) / 1e18;
        ERC20(yToken).safeTransfer(msg.sender, amount);

        emit Unstake(msg.sender, amount);
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
     */
    function _claimRewards(address user) internal {
        if (userInfo[user].amount == 0) {
            return;
        }

        uint256 pending = pendingRewards(user);
        if (pending != 0) {
            ERC20(reward).safeTransfer(user, pending);
            claimedRewards += pending;
        }

        emit Claim(user, pending);
    }

    //////////////////////////
    /* Restricted Functions */
    //////////////////////////

    /**
     * @notice Distributes rebase rewards from vault to yToken stakers
     * @dev Rebase rewards from unclaimed rewards are redistributed to stakers
     */
    function distribute() external override {
        require(msg.sender == vault, "!vault");
        uint256 totalStaked = ERC20(yToken).balanceOf(address(this));
        require(totalStaked != 0, "totalStaked is 0");
        uint256 balance = ERC20(reward).balanceOf(address(this));
        uint256 amount = balance + claimedRewards - accRewards;
        accRewardsPerShare += (amount * 1e18) / totalStaked;
        accRewards += amount;

        emit Distribute(amount, accRewardsPerShare);
    }
}
