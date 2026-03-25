// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "./InterestRateModel.sol";
import "./RiskManager.sol";
import "./SimplePriceOracle.sol";

/**
 * @title MiniLend Lending Protocol
 * @author LanPenn
 * @notice A simplified decentralized lending protocol that supports
 * asset deposit, borrowing, repayment, and liquidation.
 * @dev The protocol integrates:
 * - InterestRateModel for dynamic interest calculation
 * - RiskManager for LTV and liquidation checks
 * - SimplePriceOracle for asset pricing
 */
contract MiniLend is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;
    InterestRateModel interestRateModel;
    RiskManager riskManager;

    error MiniLend__AmountZero();
    error MiniLend__NotAllowed();
    error MiniLend__HealthFactorTooLow();
    error MiniLend__Paused();

    struct UserInfo {
        uint256 deposited;
        uint256 borrowed;
        uint256 collateral;
        uint256 depositLastUpdate; //最后计息时间
        uint256 borrowLastUpdate;
    }
    // 1.借贷阈值，2.利息，3.
    IERC20 public immutable asset; //借贷资产
    IERC20 public immutable collateral; //抵押资产
    SimplePriceOracle public oracle; //预言机

    //系统总量
    uint256 public totalDeposits;
    uint256 public totalBorrows;
    uint256 public totalCollateral;

    mapping(address => UserInfo) public users;

    event Deposited(address indexed user, uint256 amount, uint256 time);
    event Withdrawn(address indexed user, uint256 amount, uint256 time);
    event DepositCollateral(address indexed user, uint256 collateral, uint256 time);
    event WithdrawCollateral(address indexed user, uint256 collateral, uint256 time);
    event Borrowed(address indexed user, uint256 amount, uint256 time);
    event Repaid(address indexed user, uint256 amount, uint256 time);
    event Liquidated(
        address indexed user, address indexed liquidator, uint256 repayAmount, uint256 liquidate, uint256 time
    );
    event RiskParamsUpdated(
        uint256 newMaxLTV, uint256 newLiquidationThreshold, uint256 newLiquidationBonus, uint256 newCloseFactor
    );

    constructor(
        address _asset,
        address _collateral,
        address _oracle,
        InterestRateModel _interestRateModel,
        RiskManager _riskManager
    ) Ownable(msg.sender) {
        asset = IERC20(_asset);
        collateral = IERC20(_collateral);
        oracle = SimplePriceOracle(_oracle);
        interestRateModel = _interestRateModel;
        riskManager = _riskManager;
    }

    modifier whenNotPaused() {
        if (riskManager.paused()) revert MiniLend__Paused();
        _;
    }


        /**
     * @notice Deposit asset tokens into the protocol
     * @param amount The amount of asset to deposit
     * @dev Accrues pending interest before updating user balance
     */
    function depositAsset(uint256 amount) external nonReentrant whenNotPaused {
        if (amount == 0) revert MiniLend__AmountZero();
        asset.safeTransferFrom(msg.sender, address(this), amount);

        UserInfo storage user = users[msg.sender];
        uint256 currentTime = block.timestamp;
        uint256 interest = 0;
        // 利息
        if (user.deposited != 0) {
            interest = _calculateDepositInterest(user.deposited, user.depositLastUpdate, currentTime);
        }
        uint256 increment = amount + interest;
        user.deposited += increment;
        user.depositLastUpdate = currentTime;
        totalDeposits += increment;

        emit Deposited(msg.sender, amount, currentTime);
    }


    /**
     * @notice Withdraw deposited assets from the protocol
     * @param amount The amount to withdraw
     * @dev Includes interest calculation and ensures sufficient liquidity
     */
    function withdrawAsset(uint256 amount) external nonReentrant whenNotPaused {
        if (amount == 0) revert MiniLend__AmountZero();
        UserInfo storage user = users[msg.sender];
        //利息
        uint256 currentTime = block.timestamp;
        uint256 interest = 0;
        if (user.deposited != 0) {
            interest = _calculateDepositInterest(user.deposited, user.depositLastUpdate, currentTime);
        }

        if (amount > user.deposited + interest || asset.balanceOf(address(this)) < amount) {
            revert MiniLend__NotAllowed();
        }
        uint256 increment = amount > interest ? amount - interest : interest - amount;
        if (interest > amount) {
            user.deposited += increment;
            totalDeposits += increment;
        } else {
            user.deposited -= increment;
            totalDeposits -= increment;
        }

        user.depositLastUpdate = block.timestamp;
        asset.safeTransfer(msg.sender, amount);

        emit Withdrawn(msg.sender, amount, currentTime);
    }


       /**
     * @notice Deposit collateral to enable borrowing
     * @param amount The amount of collateral to deposit
     * @dev Collateral increases user's borrowing capacity
     */
    function depositCollateral(uint256 amount) external nonReentrant whenNotPaused {
        if (amount == 0) revert MiniLend__AmountZero();

        collateral.safeTransferFrom(msg.sender, address(this), amount);

        UserInfo storage user = users[msg.sender];
        user.collateral += amount;
        // user.lastInterest = block.timestamp;
        totalCollateral += amount;

        emit DepositCollateral(msg.sender, amount, block.timestamp);
    }

    
        /**
     * @notice Withdraw collateral from the protocol
     * @param amount The amount of collateral to withdraw
     * @dev Ensures user's health factor remains above liquidation threshold
     */
    function withdrawCollateral(uint256 amount) external nonReentrant whenNotPaused {
        if (amount == 0) revert MiniLend__AmountZero();
        UserInfo storage user = users[msg.sender];
        uint256 oldcollateral = user.collateral;
        if (amount > oldcollateral) revert MiniLend__NotAllowed();

        uint256 newCollateral = oldcollateral - amount;
        //检查健康状态
        if (riskManager.canBeLiquidated(user.borrowed, newCollateral, getAssetPrice(), getCollateralPrice())) {
            revert MiniLend__HealthFactorTooLow();
        }
        user.collateral -= amount;
        // user.lastInterest = block.timestamp;
        totalCollateral -= amount;
        collateral.safeTransfer(msg.sender, amount);

        emit WithdrawCollateral(msg.sender, amount, block.timestamp);
    }


    /**
     * @notice Borrow assets based on deposited collateral
     * @param amount The amount to borrow
     * @dev Checks LTV constraints and accrues interest before borrowing
     */
    function borrow(uint256 amount) external nonReentrant whenNotPaused {
        if (amount == 0) revert MiniLend__AmountZero();
        UserInfo storage user = users[msg.sender];
        uint256 oldBorrowed = user.borrowed;
        // 利息
        uint256 interest = 0;
        uint256 currentTime = block.timestamp;
        if (oldBorrowed != 0) {
            interest = _calculateBorrowInterest(oldBorrowed, user.borrowLastUpdate, currentTime);
        }
        if (
            !riskManager.canBorrow(
                    oldBorrowed + amount + interest, user.collateral, getAssetPrice(), getCollateralPrice()
                ) || asset.balanceOf(address(this)) < amount
        ) {
            revert MiniLend__HealthFactorTooLow();
        }
        uint256 increment = amount + interest;
        user.borrowLastUpdate = currentTime;
        user.borrowed += increment;
        totalBorrows += increment;
        // user.lastInterest = block.timestamp;
        asset.safeTransfer(msg.sender, amount);

        emit Borrowed(msg.sender, amount, currentTime);
    }


    /**
     * @notice Repay borrowed assets
     * @param amount The amount to repay
     * @dev Repayment first covers interest, then reduces principal debt
     */
    function repay(uint256 amount) external nonReentrant whenNotPaused {
        if (amount == 0) revert MiniLend__AmountZero();
        UserInfo storage user = users[msg.sender];
        uint256 oldBorrowed = user.borrowed;
        uint256 currentTime = block.timestamp;
        uint256 interest = 0;
        // 利息
        if (oldBorrowed != 0) interest = _calculateBorrowInterest(oldBorrowed, user.borrowLastUpdate, currentTime);
        uint256 needRepay = oldBorrowed + interest;
        require(needRepay > 0, "don't need to repay");
        if (amount > needRepay) amount = needRepay;

        if (amount > interest) {
            uint256 increment = amount - interest;
            user.borrowed -= increment;
            totalBorrows -= increment;
        } else {
            uint256 increment = interest - amount;
            user.borrowed += increment;
            totalBorrows += increment;
        }

        asset.safeTransferFrom(msg.sender, address(this), amount);
        user.borrowLastUpdate = currentTime;

        emit Repaid(msg.sender, amount, currentTime);
    }


    /**
     * @notice Liquidate an undercollateralized position
     * @param user The borrower to be liquidated
     * @param debtToCover The amount of debt to repay during liquidation
     * @dev Can only be executed when user's health factor is below threshold
     */
    function liquidate(address user, uint256 debtToCover) external nonReentrant {
        UserInfo storage borrower = users[user];
        uint256 debt = borrower.borrowed;
        uint256 oldcollateral = borrower.collateral;
        uint256 assetPrice = getAssetPrice();
        uint256 collPrice = getCollateralPrice();
        if (!riskManager.canBeLiquidated(debt, oldcollateral, assetPrice, collPrice)) {
            revert MiniLend__NotAllowed();
        }
        uint256 maxLiquidate = borrower.borrowed * riskManager.closeFactor() / 10000;
        if (debtToCover > maxLiquidate) revert("over maxLiquidate");

        uint256 collateralToGive = riskManager.calculateLiquidationAmount(debtToCover, assetPrice, collPrice);
        if (collateralToGive > oldcollateral) collateralToGive = oldcollateral;
       //利息
        uint256 currentTime = block.timestamp;
        uint256 interest = _calculateBorrowInterest(debt, borrower.borrowLastUpdate, currentTime);
        uint256 increment = debtToCover-interest;
        asset.safeTransferFrom(msg.sender, address(this), debtToCover);
        borrower.borrowLastUpdate = currentTime;
        borrower.borrowed -= increment;
        totalBorrows -= increment;
        borrower.collateral -= collateralToGive;
        totalCollateral -= collateralToGive;
        collateral.safeTransfer(msg.sender, collateralToGive);

        emit Liquidated(user, msg.sender, debtToCover, collateralToGive,currentTime );
    }


    /**
     * @notice Get the current price of collateral asset from oracle
     * @return price The collateral price
     */
    function getCollateralPrice() public view returns (uint256 price) {
        // 根据预言及获取clllateral币的单价
        return oracle.getPrice(address(collateral));
    }

    /**
     * @notice Get the current price of lending asset from oracle
     * @return price The asset price
     */
    function getAssetPrice() public view returns (uint256 price) {
        // 根据预言及获取Asset币的单价
        return oracle.getPrice(address(asset));
    }


    /**
     * @notice Calculate the health factor of a user
     * @param user The address of the user
     * @return The health factor value (higher is safer)
     * @dev Returns max value if user has no debt
     */
    function healthFactor(address user) external view returns (uint256) {
        UserInfo storage us = users[user];
        uint256 collateralValue = getCollateralPrice() * us.collateral;
        uint256 borrowValue = getAssetPrice() * us.borrowed;
        if (borrowValue == 0) return type(uint256).max;
        return collateralValue * riskManager.liquidationThreshold() * 1e18 / borrowValue;
    }


    /**
     * @notice Get the maximum borrowable amount for a user
     * @param user The address of the user
     * @return The remaining borrow limit
     */
    function borrowLimit(address user) external view returns (uint256) {
        UserInfo storage us = users[user];
        uint256 limit = us.collateral * getCollateralPrice() * riskManager.LTV()/10000 / getAssetPrice()-us.borrowed;
        return limit;
    }


    /**
     * @notice Internal function to calculate deposit interest
     * @dev Uses interest rate model based on utilization
     */
    function _calculateDepositInterest(uint256 deposited, uint256 depositLastUpdate, uint256 currentTime) internal view returns (uint256){
        return interestRateModel.calculateDepositInterest(
            deposited, depositLastUpdate, totalDeposits, totalBorrows, currentTime
        );
    }


    /**
     * @notice Internal function to calculate borrow interest
     * @dev Interest accrues over time based on system utilization
     */
    function _calculateBorrowInterest(uint256 borrowed, uint256 borrowLastUpdate, uint256 currentTime) internal view returns (uint256){
        return interestRateModel.calculateBorrowInterest(
            borrowed, borrowLastUpdate, totalDeposits, totalBorrows, currentTime
        );
    }
}
