// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

interface IPerpetualBondToken {
    function vault() external view returns (address);

    function mint(address user, uint256 amount) external;

    function burn(address user, uint256 amount) external;
}
