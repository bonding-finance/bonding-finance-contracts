// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "./interfaces/IEscrowedBondingToken.sol";
import "./BondingToken.sol";
import "../erc20/ERC20.sol";
import "../erc20/SafeERC20.sol";
import "../utils/Owned.sol";

/**
 * @title Escrowed Bonding Finance DAO Token
 * @author Bonding Finance
 */
contract EscrowedBondingToken is IEscrowedBondingToken, ERC20, Owned {
    using SafeERC20 for ERC20;

    address public immutable override bnd;
    uint256 public immutable override vestingDuration;

    mapping(address => VestingDetails) public override vestingInfo;
    mapping(address => bool) public override minters;
    mapping(address => bool) public override transferers;

    constructor(uint256 _vestingDuration) ERC20("Escrowed Bonding Finance Token", "esBND", 18) {
        vestingDuration = _vestingDuration;

        bnd = address(new BondingToken{salt: keccak256(abi.encode("BND"))}());
    }

    /**
     * @notice Vests `amount` of esBND linearly over vesting period
     * @dev Claims unlocked BND
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
     * @notice Internal function to claim unlocked BND
     * @param user User to claim for
     * @return amount Amount of BND claimed
     */
    function _claim(address user) internal returns (uint256 amount) {
        _updateVesting(user);
        amount = claimable(user);
        vestingInfo[user].claimedAmount += amount;
        BondingToken(bnd).mint(user, amount);

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

    function mint(address user, uint256 amount) external override {
        require(minters[msg.sender], "!minter");
        _mint(user, amount);
    }

    function setMinter(address minter, bool allowed) external override onlyOwner {
        minters[minter] = allowed;
    }
}
