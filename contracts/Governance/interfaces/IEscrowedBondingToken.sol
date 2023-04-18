// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

interface IEscrowedBondingToken {
    event Claim(address indexed user, uint256 amount);

    struct VestingDetails {
        uint256 vestingAmount;
        uint256 cumulativeClaimAmount;
        uint256 claimedAmount;
        uint256 lastVestingTime;
    }

    function bondingToken() external view returns (address);

    function vestingDuration() external view returns (uint256);

    function vestingInfo(
        address user
    )
        external
        view
        returns (
            uint256 vestingAmount,
            uint256 cumulativeClaimAmount,
            uint256 claimedAmunt,
            uint256 lastVestingTime
        );

    function minters(address) external view returns (bool);

    function vest(uint256 amount) external;

    function claim() external returns (uint256 amount);

    function claimable(address user) external view returns (uint256 amount);

    function mint(address user, uint256 amount) external;

    function setMinter(address minter, bool allowed) external;
}
