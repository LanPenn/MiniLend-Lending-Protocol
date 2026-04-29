// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title Risk Manager
 * @notice Handles risk control logic such as borrowing limits and liquidation conditions
 * @dev Defines LTV, liquidation threshold, bonus, and close factor parameters
 */
contract RiskManager is Ownable {
    constructor() Ownable(msg.sender) {}
    // 借贷阈值参数
    uint256 public LTV = 7500; //75%
    uint256 public liquidationThreshold = 8000; //80%清算
    uint256 public liquidation_bonus = 500; //5%奖励
    uint256 public closeFactor = 5000; //最多清算50%

    bool public paused;

    event RiskParamsUpdated(
        uint256 newLTV, uint256 newLiquidationThreshold, uint256 newLiquidationBonus, uint256 newCloseFactor
    );
    event Paused(bool paused);
    error InvalidRiskParams(string reason);

    modifier validRiskParams(uint256 _ltv, uint256 _threshold, uint256 _bonus, uint256 _closeFactor) {
        require(_ltv <= 9000, "LTV too high"); // 最多 90%
        require(_threshold >= _ltv, "Threshold must be >= LTV"); // 清算线必须 >= 借款线
        require(_threshold <= 9500, "Threshold too high");
        require(_bonus <= 2000, "Bonus too high"); // 奖励最多 20%
        require(_closeFactor <= 10000, "Close factor invalid");
        _;
    }

//预言机代币地址
 mapping(address => address) public priceFeeds;

/**
 * @notice Update risk parameters of the protocol
 * @param _ltv Loan-to-value ratio (max borrow ratio)
 * @param _threshold Liquidation threshold
 * @param _bonus Liquidation bonus for liquidators
 * @param _closeFactor Maximum percentage of debt that can be liquidated
 * @dev Only callable by owner, parameters validated by modifier
 */
    function updateRiskParams(uint256 _ltv, uint256 _threshold, uint256 _bonus, uint256 _closeFactor)
        external
        onlyOwner
        validRiskParams(_ltv, _threshold, _bonus, _closeFactor)
    {
        LTV = _ltv;
        liquidationThreshold = _threshold;
        liquidation_bonus = _bonus;
        closeFactor = _closeFactor;
    }


/**
 * @notice Pause or unpause the protocol
 * @param _paused True to pause, false to unpause
 * @dev Used as an emergency stop mechanism
 */
    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
        emit Paused(_paused);
    }


/**
 * @notice Check if a user can borrow based on collateral
 * @param borrowed Total borrowed amount (including new borrow)
 * @param collateral User's collateral amount
 * @param assetPrice Price of borrowed asset
 * @param collPrice Price of collateral asset
 * @return True if borrowing is allowed
 * @dev Enforces LTV constraint
 */
    function canBorrow(uint256 borrowed, uint256 collateral, uint256 assetPrice, uint256 collPrice)
        external
        view
        returns (bool)
    {
        uint256 collateralValue = collPrice * collateral;
        uint256 borrowValue = assetPrice * borrowed;
        return borrowValue * 10000 <= collateralValue * LTV;
    }


/**
 * @notice Check if a position is eligible for liquidation
 * @param borrowed User's borrowed amount
 * @param collateral User's collateral amount
 * @param assetPrice Price of borrowed asset
 * @param collPrice Price of collateral asset
 * @return True if position can be liquidated
 * @dev Triggered when borrow value exceeds liquidation threshold
 */
    function canBeLiquidated(uint256 borrowed, uint256 collateral, uint256 assetPrice, uint256 collPrice)
        external
        view
        returns (bool)
    {
        uint256 collateralValue = collPrice * collateral;
        uint256 borrowValue = assetPrice * borrowed;
        return borrowValue * 10000 > collateralValue * liquidationThreshold;
    }


/**
 * @notice Calculate collateral amount to seize during liquidation
 * @param debtToCover Amount of debt to repay
 * @param assetPrice Price of borrowed asset
 * @param collPrice Price of collateral asset
 * @return Amount of collateral to be transferred to liquidator
 * @dev Includes liquidation bonus
 */
    function calculateLiquidationAmount(uint256 debtToCover, uint256 assetPrice, uint256 collPrice)
        external
        view
        returns (uint256)
    {
        return Math.mulDiv(debtToCover * assetPrice, (10000 + liquidation_bonus), collPrice * 10000);
    }


    function setPriceFeed(address token, address feed) external onlyOwner {
    priceFeeds[token] = feed;
}
}

