// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

/**
 * @title Bond token interface
 * @author Bonding Finance
 */
interface IBondToken {
    function vault() external view returns (address);

    //////////////////////////
    /* Restricted Functions */
    //////////////////////////

    function mint(address user, uint256 amount) external;

    function burn(address user, uint256 amount) external;
}
