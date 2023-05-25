// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "./interfaces/IPerpetualBondVault.sol";
import "./interfaces/IPerpetualBondFactory.sol";
import "./interfaces/IPerpetualBondStaking.sol";
import "../BondToken/BondToken.sol";
import "./PerpetualBondDeployer.sol";
import "../erc20/SafeERC20.sol";
import "../erc20/ERC20.sol";
import "../erc20/ERC20.sol";
import "../utils/ReentrancyGuard.sol";

/**
 * @title Perpetual bond vault contract
 * @author Bonding Finance
 */
contract PerpetualBondVault is IPerpetualBondVault, ReentrancyGuard {
    using SafeERC20 for ERC20;

    address public immutable override factory;
    address public immutable override token;
    address public immutable override dToken;
    address public immutable override yToken;
    address public override staking;
    uint256 public override totalDeposits;
    uint256 public override fees;

    constructor() {
        (factory, token) = PerpetualBondDeployer(msg.sender).parameters();

        string memory tokenSymbol = ERC20(token).symbol();
        uint8 decimals = ERC20(token).decimals();

        dToken = address(
            new BondToken{salt: keccak256(abi.encode(token))}(
                string(abi.encodePacked(tokenSymbol, " Deposit Token")),
                string(abi.encodePacked(tokenSymbol, "-D")),
                decimals
            )
        );

        yToken = address(
            new BondToken{salt: keccak256(abi.encode(token))}(
                string(abi.encodePacked(tokenSymbol, " Yield Token")),
                string(abi.encodePacked(tokenSymbol, "-Y")),
                decimals
            )
        );
    }

    /**
     * @notice Deposit `amount` underlying tokens to mint `amount` dTokens and `amount` yTokens
     * @param amount Amount of underlying tokens to deposit
     * @return mintAmount Amount of dTokens and yTokens minted
     */
    function deposit(uint256 amount) external override nonReentrant returns (uint256 mintAmount) {
        _isNotPaused();

        ERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        uint256 feeAmount = _chargeFee(amount);
        mintAmount = amount - feeAmount;
        totalDeposits += mintAmount;

        BondToken(dToken).mint(msg.sender, mintAmount);
        BondToken(yToken).mint(msg.sender, mintAmount);

        emit Mint(msg.sender, mintAmount);
    }

    /**
     * @notice Burn `amount` of dTokens and yTokens for underlying tokens
     * @param amount Amount of dTokens and yTokens to burn
     * @return redeemAmount The amount of underlying tokens redeemed
     */
    function redeem(uint256 amount) external override nonReentrant returns (uint256 redeemAmount) {
        _isNotPaused();

        BondToken(dToken).burn(msg.sender, amount);
        BondToken(yToken).burn(msg.sender, amount);
        totalDeposits -= amount;

        uint256 feeAmount = _chargeFee(amount);
        redeemAmount = amount - feeAmount;

        uint256 balance = ERC20(token).balanceOf(address(this));
        // In case of rounding error
        if (redeemAmount > balance) redeemAmount = balance;

        ERC20(token).safeTransfer(msg.sender, redeemAmount);

        emit Redeem(msg.sender, redeemAmount);
    }

    /**
     * @notice Collects pending rebase rewards and sends to staking contract to distribute
     * @dev Will return if `staking` or pending rewards is 0
     */
    function harvest() public override {
        if (staking == address(0)) return;

        uint256 amount = pendingRewards();
        if (amount == 0) return;

        ERC20(token).safeTransfer(staking, amount);

        emit Harvest(amount);
    }

    /**
     * @notice Calculates rebase yield that hasn't been distributed to staking contract
     * @return rewards Amount of pending rewards
     */
    function pendingRewards() public view override returns (uint256 rewards) {
        uint256 balance = ERC20(token).balanceOf(address(this));
        if (totalDeposits + fees >= balance) return 0;

        rewards = balance - totalDeposits - fees;
    }

    /**
     * @notice Applies vault fee (if any) to `amount`
     * @param amount The original amount
     * @return feeAmount The fee amount charged
     */
    function _chargeFee(uint256 amount) internal returns (uint256 feeAmount) {
        (, uint256 fee, ) = IPerpetualBondFactory(factory).feeInfo();
        if (fee == 0) return 0;

        feeAmount = (amount * fee) / 10000;
        fees += feeAmount;
    }

    function _isNotPaused() internal view {
        require(!IPerpetualBondFactory(factory).paused(), "paused");
    }

    //////////////////////////
    /* Restricted Functions */
    //////////////////////////

    function setStaking(address _staking) external override {
        require(msg.sender == factory, "!factory");

        staking = _staking;
    }

    function collectFees(address feeTo) external override {
        require(msg.sender == factory, "!factory");

        if (fees == 0) return;

        ERC20(token).safeTransfer(feeTo, fees);

        emit CollectFees(feeTo, fees);

        delete fees;
    }
}
