// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

/**
 * @title Escrowed Bonding Finance DAO token interface
 * @author Bonding Finance
 */
interface IEscrowedBondingFinanceToken {
    event Claim(address indexed user, uint256 i, uint256 amount);

    struct VestingDetails {
        uint256 vestingAmount;
        uint256 cumulativeClaimAmount;
        uint256 claimedAmount;
        uint256 lastVestingTime;
    }

    function bnd() external view returns (address);

    function vestingDuration() external view returns (uint256);

    function userInfo(
        address user,
        uint256 index
    )
        external
        view
        returns (
            uint256 vestingAmount,
            uint256 cumulativeClaimAmount,
            uint256 claimedAmount,
            uint256 lastVestingTime
        );

    function transferers(address) external view returns (bool);

    function vest(uint256 amount) external;

    function claim(uint256 index) external;

    function claimMany(uint256[] calldata indexes) external;

    function userInfoLength(address user) external view returns (uint256);

    function claimable(address user, uint256 index) external view returns (uint256 amount);

    function setTransferer(address transferer, bool allowed) external;
}
