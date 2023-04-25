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
    uint256 public constant override vestingDuration = 365 days;

    mapping(address => bool) public override transferers;
    mapping(address => VestingDetails[]) public override userInfo;

    constructor() ERC20("Escrowed Bonding Finance Token", "esBND", 18) {
        _mint(msg.sender, 1_000_000 ether);
        transferers[msg.sender] = true;

        bnd = address(
            new BondingFinanceToken{salt: keccak256(abi.encode("Bonding Finance Token"))}()
        );
    }

    /**
     * @notice Vests `amount` of esBND linearly over vesting period
     * @param amount Amount of esBND to vest
     */
    function vest(uint256 amount) external override {
        require(amount != 0, "amount is 0");

        _burn(msg.sender, amount);

        userInfo[msg.sender].push(
            VestingDetails({
                vestingAmount: amount,
                cumulativeClaimAmount: 0,
                claimedAmount: 0,
                lastVestingTime: block.timestamp
            })
        );
    }

    /**
     * @notice Claims unlocked BND
     * @param index Index of vests
     */
    function claim(uint256 index) external override {
        _claim(msg.sender, index);
    }

    /**
     * @notice Claims unlocked BND from multiple vests
     * @param indexes Indexes of vests
     */
    function claimMany(uint256[] calldata indexes) external override {
        uint256 length = indexes.length;
        for (uint256 i; i < length; ) {
            _claim(msg.sender, indexes[i]);

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Calculates amount of unlocked BND for `user` per vesting schedule
     * @param user User to check claimable amount
     * @param index Index of vests
     * @return amount Amount of claimable BND
     */
    function claimable(address user, uint256 index) external view returns (uint256 amount) {
        VestingDetails storage vestingDetails = userInfo[user][index];
        amount = _claimable(vestingDetails);
    }

    function userInfoLength(address user) public view override returns (uint256) {
        return userInfo[user].length;
    }

    /**
     * @notice Claims unlocked BND and sends to `user`
     * @param user User to claim for
     * @param i Index of vesting details
     */
    function _claim(address user, uint256 i) internal {
        if (i >= userInfoLength(msg.sender)) return;

        VestingDetails storage vestingDetails = userInfo[user][i];

        _updateVesting(vestingDetails);

        uint256 amount = _claimable(vestingDetails);
        if (amount == 0) return;

        userInfo[user][i].claimedAmount += amount;
        ERC20(bnd).transfer(user, amount);

        emit Claim(user, i, amount);
    }

    /**
     * @notice Updates vesting details
     * @dev Updates last vesting time and increments cumulative claim amount
     * @param vestingDetails User's vesting details
     */
    function _updateVesting(VestingDetails storage vestingDetails) internal {
        uint256 amount = _getNextClaimableAmount(vestingDetails);
        vestingDetails.lastVestingTime = block.timestamp;

        if (amount == 0) return;

        vestingDetails.cumulativeClaimAmount += amount;
    }

    /**
     * @notice Calculates amount of unlocked BND for `user` per vesting schedule
     * @param vestingDetails User's vesting details
     * @return amount Amount of claimable BND
     */
    function _claimable(
        VestingDetails storage vestingDetails
    ) internal view returns (uint256 amount) {
        uint256 currentClaimable = vestingDetails.cumulativeClaimAmount -
            vestingDetails.claimedAmount;
        uint256 nextClaimable = _getNextClaimableAmount(vestingDetails);

        amount = currentClaimable + nextClaimable;
    }

    /**
     * @notice Calculates amount claimable since last claim
     * @param vestingDetails User's vesting details
     * @return claimableAmount Amount of BND claimable since last claim
     */
    function _getNextClaimableAmount(
        VestingDetails storage vestingDetails
    ) internal view returns (uint256 claimableAmount) {
        if (vestingDetails.vestingAmount == 0) return 0;

        uint256 timeDiff = block.timestamp - vestingDetails.lastVestingTime;
        claimableAmount = (vestingDetails.vestingAmount * timeDiff) / vestingDuration;
        if (claimableAmount + vestingDetails.cumulativeClaimAmount > vestingDetails.vestingAmount) {
            return vestingDetails.vestingAmount - vestingDetails.cumulativeClaimAmount;
        }

        return claimableAmount;
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
