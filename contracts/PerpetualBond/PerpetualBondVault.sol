// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "./interfaces/IPerpetualBondVault.sol";
import "./interfaces/IPerpetualBondFactory.sol";
import "./PerpetualBondToken.sol";
import "./PerpetualBondStaking.sol";
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
    address public immutable override staking;
    uint256 public override totalDeposits;

    constructor() {
        (factory, token) = PerpetualBondDeployer(msg.sender).parameters();

        string memory tokenSymbol = ERC20(token).symbol();
        uint8 decimals = ERC20(token).decimals();

        dToken = address(
            new PerpetualBondToken{salt: keccak256(abi.encode(token))}(
                string(abi.encodePacked(tokenSymbol, " Deposit")),
                string(abi.encodePacked(tokenSymbol, "-D")),
                decimals
            )
        );

        yToken = address(
            new PerpetualBondToken{salt: keccak256(abi.encode(token))}(
                string(abi.encodePacked(tokenSymbol, " Yield")),
                string(abi.encodePacked(tokenSymbol, "-Y")),
                decimals
            )
        );

        staking = address(
            new PerpetualBondStaking{salt: keccak256(abi.encode(token))}(factory, yToken, token)
        );
    }

    /**
     * @notice Calculates rebase yield that hasn't been distributed to staking contract
     * @return amount Amount of pending rewards
     */
    function pendingRewards() public view override returns (uint256 amount) {
        uint256 balance = ERC20(token).balanceOf(address(this));
        if (totalDeposits >= balance) return 0;

        amount = balance - totalDeposits;
    }

    /**
     * @notice Deposit `amount` underlying tokens to mint dTokens and yTokens
     * @param amount Amount of underlying tokens to deposit
     * @return mintAmount Amount of dTokens and yTokens minted
     */
    function mint(uint256 amount) external override nonReentrant returns (uint256 mintAmount) {
        ERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        uint256 feeAmount = _chargeFee(amount);
        mintAmount = amount - feeAmount;
        totalDeposits += mintAmount;

        PerpetualBondToken(dToken).mint(msg.sender, mintAmount);
        PerpetualBondToken(yToken).mint(msg.sender, mintAmount);

        emit Mint(msg.sender, mintAmount);

        return mintAmount;
    }

    /**
     * @notice Redeem `amount` of dTokens and yTokens for underlying tokens
     * @param amount Amount of dTokens and yTokens to burn
     * @return redeemAmount The amount of underlying tokens redeemed
     */
    function redeem(uint256 amount) external override nonReentrant returns (uint256 redeemAmount) {
        PerpetualBondToken(dToken).burn(msg.sender, amount);
        PerpetualBondToken(yToken).burn(msg.sender, amount);
        totalDeposits -= amount;

        uint256 feeAmount = _chargeFee(amount);
        redeemAmount = amount - feeAmount;

        ERC20(token).safeTransfer(msg.sender, redeemAmount);

        emit Redeem(msg.sender, redeemAmount);

        return redeemAmount;
    }

    /**
     * @notice Collects pending rebase rewards and sends to staking contract to distribute
     */
    function harvest() external override nonReentrant {
        uint256 amount = pendingRewards();
        if (amount == 0) return;

        ERC20(token).safeTransfer(staking, amount);
        PerpetualBondStaking(staking).distribute();

        emit Harvest(amount);
    }

    /**
     * @notice Applies fee (if any) to `amount`
     * @param amount The original amount
     * @return feeAmount The fee amount charged
     */
    function _chargeFee(uint256 amount) internal returns (uint256 feeAmount) {
        (address feeTo, uint256 fee) = IPerpetualBondFactory(factory).feeInfo();
        if (feeTo == address(0) || fee == 0) {
            return 0;
        }

        feeAmount = (amount * fee) / 10000;
        ERC20(token).safeTransfer(feeTo, feeAmount);

        return feeAmount;
    }
}
