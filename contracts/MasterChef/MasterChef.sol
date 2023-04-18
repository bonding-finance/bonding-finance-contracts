// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "../erc20/ERC20.sol";
import "../erc20/SafeERC20.sol";
import "../utils/ReentrancyGuard.sol";

/**
 * @title MasterChef
 * @author Bonding Finance
 * @notice Modified from SushiSwap MasterChef (https://github.com/sushiswap/sushiswap/blob/master/protocols/masterchef/contracts/MasterChef.sol)
 */
contract MasterChef is ReentrancyGuard {
    using SafeERC20 for ERC20;
}
