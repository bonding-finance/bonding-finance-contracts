// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "./interfaces/IEscrowedBondingFinanceToken.sol";
import "./BondingFinanceToken.sol";
import "../erc20/ERC20.sol";
import "../erc20/SafeERC20.sol";
import "../utils/Owned.sol";

/**
 * @title Escrowed Bonding Finance DAO Token
 * @author Bonding Finance
 */
contract EscrowedBondingFinanceToken is IEscrowedBondingFinanceToken, ERC20, Owned {
    using SafeERC20 for ERC20;

    address public immutable override bnd;
    uint256 public immutable override vestingDuration;

    mapping(address => VestingDetails) public override vestingInfo;
    mapping(address => bool) public override transferers;

    constructor(uint256 _vestingDuration) ERC20("Escrowed Bonding Finance Token", "esBND", 18) {
        _mint(msg.sender, 1_000_000 ether);

        vestingDuration = _vestingDuration;
        bnd = address(new BondingFinanceToken{salt: keccak256(abi.encode("Bonding Finance Token"))}());
    }

    /**
     * @notice Vests `amount` of esBND linearly over vesting period
     * @dev Will only claim if amount is 0
     * @param amount Amount of esBND to vest
     */
    function vest(uint256 amount) external override {
        _claim(msg.sender);

        if (amount == 0) return;
        _burn(msg.sender, amount);

        vestingInfo[msg.sender].vestingAmount += amount;
    }

    /**
     * @notice Calculates amount of unlocked BND for `user`
     * @param user User to check claimable amount
     * @return amount Amount of claimable BND
     */
    function claimable(address user) public view override returns (uint256 amount) {
        VestingDetails memory info = vestingInfo[user];
        uint256 currentClaimable = info.cumulativeClaimAmount - info.claimedAmount;
        uint256 nextClaimable = _getNextClaimableAmount(user);

        amount = currentClaimable + nextClaimable;
    }

    /**
     * @notice Claims and sends BND to `user`
     * @param user User to claim for
     * @return amount Amount of BND claimed
     */
    function _claim(address user) internal returns (uint256 amount) {
        _updateVesting(user);

        amount = claimable(user);
        vestingInfo[user].claimedAmount += amount;

        ERC20(bnd).transfer(user, amount);

        emit Claim(user, amount);
    }

    /**
     * @notice Updates vesting details
     * @dev Updates last vesting time and increments cumulative claim amount
     * @param user User to claim for
     */
    function _updateVesting(address user) internal {
        uint256 amount = _getNextClaimableAmount(user);

        VestingDetails storage info = vestingInfo[user];
        info.lastVestingTime = block.timestamp;
        info.cumulativeClaimAmount += amount;
    }

    /**
     * @notice Calculates amount claimable since last claim
     * @param user User to claim for
     * @return claimableAmount Amount of BND claimable since last claim
     */
    function _getNextClaimableAmount(address user) internal view returns (uint256 claimableAmount) {
        VestingDetails memory info = vestingInfo[user];
        if (info.vestingAmount == 0) return 0;

        uint256 timeDiff = block.timestamp - info.lastVestingTime;
        claimableAmount = (info.vestingAmount * timeDiff) / vestingDuration;
        if (claimableAmount > info.vestingAmount) {
            claimableAmount = info.vestingAmount;
        }
    }

    //////////////////////////
    /* Restricted Functions */
    //////////////////////////

    function transfer(address to, uint256 amount) public override returns (bool) {
        require(transferers[msg.sender], "!transferer");

        return super.transfer(to, amount);
    }

    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        require(transferers[msg.sender], "!transferer");

        return super.transferFrom(from, to, amount);
    }

    function setTransferer(address transferer, bool allowed) external override onlyOwner {
        transferers[transferer] = allowed;
    }
}
