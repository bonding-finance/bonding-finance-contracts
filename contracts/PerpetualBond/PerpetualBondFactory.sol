// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./interfaces/IPerpetualBondFactory.sol";
import "./PerpetualBondDeployer.sol";
import "../utils/Owned.sol";

/**
 * @title Perpetual bond factory contract
 * @author Bonding Finance
 */
contract PerpetualBondFactory is IPerpetualBondFactory, PerpetualBondDeployer, Owned {
    FeeInfo public override feeInfo;
    address[] public override allBonds;

    mapping(address => address) public override getBond;

    function allBondsLength() external view override returns (uint256) {
        return allBonds.length;
    }

    //////////////////////////
    /* Restricted Functions */
    //////////////////////////

    /**
     * @notice Creates the perpetual bond contract
     * @dev Deploys vault, dToken, yToken, and staking contract
     * @param token Underlying token of the bond
     * @return bond Address of the created contract
     */
    function createBond(address token) external override onlyOwner returns (address bond) {
        require(token != address(0));
        require(getBond[token] == address(0), "Bond exists");

        bond = deploy(address(this), token);
        getBond[token] = bond;
        allBonds.push(bond);

        emit BondCreated(token, bond);
    }

    function setLpToken(address staking, address lpToken) external override onlyOwner {
        require(staking != address(0));

        PerpetualBondStaking(staking).setLpToken(lpToken);
    }

    function collectFees(address staking) external override onlyOwner {
        require(staking != address(0));
        require(feeInfo.feeTo != address(0), "feeTo is 0");

        PerpetualBondStaking(staking).collectFees();
    }

    function setFeeTo(address feeTo) external override onlyOwner {
        feeInfo.feeTo = feeTo;
    }

    function setFee(uint256 fee) external override onlyOwner {
        require(fee <= 100, "Fee > 100");

        feeInfo.fee = fee;
    }
}
