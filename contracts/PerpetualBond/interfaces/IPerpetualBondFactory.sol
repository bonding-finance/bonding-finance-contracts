// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

interface IPerpetualBondFactory {
    event BondCreated(address indexed token, address bond);

    struct FeeInfo {
        address feeTo;
        uint256 fee;
    }

    function feeInfo() external view returns (address feeTo, uint256 fee);

    function allBonds(uint256) external view returns (address);

    function getBond(address token) external view returns (address);

    function allBondsLength() external view returns (uint256);

    function createBond(address token) external returns (address bond);

    function setFeeTo(address feeTo) external;

    function setFee(uint256 fee) external;
}
