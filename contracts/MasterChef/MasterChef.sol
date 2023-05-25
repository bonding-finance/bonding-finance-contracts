// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "./interfaces/IMasterChef.sol";
import "../Governance/EscrowedBondingFinanceToken.sol";
import "../erc20/ERC20.sol";
import "../erc20/SafeERC20.sol";
import "../utils/ReentrancyGuard.sol";
import "../utils/Owned.sol";

/**
 * @title Bonding Finance master chef contract
 * @author Bonding Finance
 * @notice Modified from SushiSwap MasterChef (https://github.com/sushiswap/sushiswap/blob/master/protocols/masterchef/contracts/MasterChef.sol)
 */
contract MasterChef is IMasterChef, Owned, ReentrancyGuard {
    using SafeERC20 for ERC20;

    address public immutable override esBND;
    uint256 public immutable override startBlock;
    uint256 public override rewardPerBlock;
    uint256 public override totalAllocPoint;

    PoolInfo[] public override poolInfo;
    mapping(uint256 => mapping(address => UserInfo)) public override userInfo;

    constructor(address _esBND, uint256 _startBlock, uint256 _rewardPerBlock) {
        require(_esBND != address(0));
        require(_startBlock > block.number);
        esBND = _esBND;
        startBlock = _startBlock;
        rewardPerBlock = _rewardPerBlock;
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    function pendingRewards(
        uint256 _pid,
        address _user
    ) external view override returns (uint256 rewards) {
        PoolInfo memory pool = poolInfo[_pid];
        UserInfo memory user = userInfo[_pid][_user];

        uint256 accRewardsPerShare = pool.accRewardsPerShare;
        uint256 stakedSupply = ERC20(pool.token).balanceOf(address(this));
        if (block.number > pool.lastRewardBlock && stakedSupply != 0) {
            uint256 elapsedBlocks = block.number - pool.lastRewardBlock;
            uint256 reward = (elapsedBlocks * rewardPerBlock * pool.allocPoint) / totalAllocPoint;
            accRewardsPerShare += (reward * 1e18) / stakedSupply;
        }

        rewards = ((user.amount * accRewardsPerShare) / 1e18) - user.rewardDebt;
    }

    function deposit(uint256 _pid, uint256 _amount) external override nonReentrant {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];

        updatePool(_pid);
        if (user.amount > 0) {
            uint256 pending = ((user.amount * pool.accRewardsPerShare) / 1e18) - user.rewardDebt;
            _transferRewards(msg.sender, pending);
        }
        ERC20(pool.token).safeTransferFrom(msg.sender, address(this), _amount);
        user.amount += _amount;
        user.rewardDebt = (user.amount * pool.accRewardsPerShare) / 1e18;

        emit Deposit(msg.sender, _pid, _amount);
    }

    function withdraw(uint256 _pid, uint256 _amount) external override nonReentrant {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];

        updatePool(_pid);
        uint256 pending = ((user.amount * pool.accRewardsPerShare) / 1e18) - user.rewardDebt;
        _transferRewards(msg.sender, pending);

        user.amount -= _amount;
        user.rewardDebt = (user.amount * (pool.accRewardsPerShare)) / 1e18;
        ERC20(pool.token).safeTransfer(msg.sender, _amount);

        emit Withdraw(msg.sender, _pid, _amount);
    }

    function emergencyWithdraw(uint256 _pid) external override nonReentrant {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];

        uint256 amount = user.amount;
        user.amount = 0;
        user.rewardDebt = 0;
        ERC20(pool.token).safeTransfer(msg.sender, amount);

        emit EmergencyWithdraw(msg.sender, _pid, amount);
    }

    function massUpdatePools() public override {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    function updatePool(uint256 _pid) public override {
        PoolInfo storage pool = poolInfo[_pid];

        if (block.number <= pool.lastRewardBlock) return;

        uint256 stakedSupply = ERC20(pool.token).balanceOf(address(this));
        if (stakedSupply == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }

        uint256 elapsedBlocks = block.number - pool.lastRewardBlock;
        uint256 reward = (elapsedBlocks * rewardPerBlock * pool.allocPoint) / totalAllocPoint;
        pool.accRewardsPerShare += (reward * 1e18) / stakedSupply;
        pool.lastRewardBlock = block.number;
    }

    //////////////////////////
    /* Restricted Functions */
    //////////////////////////

    function add(
        uint256 _allocPoint,
        address _token,
        bool _withUpdate
    ) external override onlyOwner {
        _checkPoolDuplicate(_token);

        if (_withUpdate) {
            massUpdatePools();
        }

        uint256 lastRewardBlock = block.number > startBlock ? block.number : startBlock;
        totalAllocPoint += _allocPoint;
        poolInfo.push(
            PoolInfo({
                token: _token,
                allocPoint: _allocPoint,
                lastRewardBlock: lastRewardBlock,
                accRewardsPerShare: 0
            })
        );
    }

    function set(uint256 _pid, uint256 _allocPoint, bool _withUpdate) external override onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }

        totalAllocPoint += _allocPoint - poolInfo[_pid].allocPoint;
        poolInfo[_pid].allocPoint = _allocPoint;
    }

    function setRewardPerBlock(
        uint256 _rewardPerBlock,
        bool _withUpdate
    ) external override onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }

        rewardPerBlock = _rewardPerBlock;
    }

    function _transferRewards(address to, uint256 amount) internal {
        uint256 balance = ERC20(esBND).balanceOf(address(this));
        if (amount > balance) amount = balance;

        ERC20(esBND).transfer(to, amount);
    }

    function _checkPoolDuplicate(address token) internal view {
        uint256 length = poolInfo.length;
        for (uint256 i = 0; i < length; ) {
            require(poolInfo[i].token != token, "!valid");

            unchecked {
                ++i;
            }
        }
    }
}
