// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
import "@openzeppelin/contracts/access/Ownable.sol";


/**
 * @title Interest Rate Model
 * @notice Defines interest rate logic for borrowing and lending
 * @dev Implements a utilization-based interest rate model similar to Aave/Compound
 */
contract InterestRateModel is Ownable {
    constructor() Ownable(msg.sender) {}

    uint256 public BASE_RATE = 2e16; // 2%
    uint256 public SLOPE1 = 10e16; // 10%
    uint256 public SLOPE2 = 50e16; // 50%
    uint256 public OPTIMAL_UTIL = 8000; // 80%
    uint256 public RESERVE_FACTOR = 1000; // 10%

    
    /**
 * @notice Update interest rate parameters
 * @param _baseRate Base interest rate
 * @param _slope1 Interest slope before optimal utilization
 * @param _slope2 Interest slope after optimal utilization
 * @param _optimalUtil Optimal utilization ratio (in basis points)
 * @param _reserveFactor Protocol reserve factor
 * @dev Only callable by owner
 */
    function setInterestRateParams(
        uint256 _baseRate,
        uint256 _slope1,
        uint256 _slope2,
        uint256 _optimalUtil,
        uint256 _reserveFactor
    ) external onlyOwner {
        BASE_RATE = _baseRate;
        SLOPE1 = _slope1;
        SLOPE2 = _slope2;
        OPTIMAL_UTIL = _optimalUtil;
        RESERVE_FACTOR = _reserveFactor;
    }


/**
 * @notice Calculate deposit interest earned by user
 * @param deposited User's deposited amount
 * @param depositLastUpdate Last timestamp of interest update
 * @param totalDeposits Total system deposits
 * @param totalBorrows Total system borrows
 * @param currentTime Current block timestamp
 * @return interest The accrued interest
 */
    function calculateDepositInterest(
        uint256 deposited,
        uint256 depositLastUpdate,
        uint256 totalDeposits,
        uint256 totalBorrows,
        uint256 currentTime
    ) external view returns (uint256) {
        uint256 supplyRate = _getSupplyRate(totalDeposits, totalBorrows);
        uint256 timeDelta = currentTime - depositLastUpdate;
        uint256 interest = supplyRate * deposited / 1e18 * timeDelta / 365 days;
        return interest;
    }


/**
 * @notice Calculate borrow interest owed by user
 * @param borrowed User's borrowed amount
 * @param borrowLastUpdate Last timestamp of interest update
 * @param totalDeposits Total system deposits
 * @param totalBorrows Total system borrows
 * @param currentTime Current block timestamp
 * @return interest The accrued interest
 */
    function calculateBorrowInterest(
        uint256 borrowed,
        uint256 borrowLastUpdate,
        uint256 totalDeposits,
        uint256 totalBorrows,
        uint256 currentTime
    ) external view returns (uint256) {
        uint256 borrowRate = _getBorrowRate(totalDeposits, totalBorrows);
        uint256 timeDelta = currentTime - borrowLastUpdate;
        uint256 interest = borrowRate * borrowed / 1e18 * timeDelta / 365 days;
        return interest;
    }


/**
 * @notice Get borrow rate based on utilization
 * @dev Piecewise model with optimal utilization threshold
 */
    function _getBorrowRate(uint256 totalDeposits, uint256 totalBorrows) internal view returns (uint256) {
        if (totalDeposits == 0) return 0;
        uint256 utilization = totalBorrows * 1e18 / totalDeposits;

        if (utilization <= OPTIMAL_UTIL * 1e14) {
            return BASE_RATE + (SLOPE1 * utilization / 1e18);
        } else {
            uint256 excessUtil = utilization - (OPTIMAL_UTIL * 1e14);
            return BASE_RATE + SLOPE1 + (SLOPE2 * excessUtil / 1e18);
        }
    }


/**
 * @notice Get supply rate for depositors
 * @dev Derived from borrow rate and utilization minus reserve factor
 */
    function _getSupplyRate(uint256 totalDeposits, uint256 totalBorrows) internal view returns (uint256) {
        if (totalDeposits == 0) return 0;
        uint256 utilization = totalBorrows * 1e18 / totalDeposits;
        uint256 borrowRate = _getBorrowRate(totalDeposits, totalBorrows);
        return borrowRate * utilization / 1e18 * (10000 - RESERVE_FACTOR) / 10000;
    }
}
