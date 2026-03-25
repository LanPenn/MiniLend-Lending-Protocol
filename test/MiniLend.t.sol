// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/MiniLend.sol";
import "../src/InterestRateModel.sol";
import "../src/RiskManager.sol";
import "../src/SimplePriceOracle.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Mock ERC20 代币用于测试
contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}
    
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract MiniLendTest is Test {
    MiniLend public lend;
    MockERC20 public asset;
    MockERC20 public collateral;
    SimplePriceOracle public oracle;
    InterestRateModel public interestModel;
    RiskManager public riskManager;
    
    address public owner;
    address public user1;
    address public user2;
    address public liquidator;
    
    uint256 constant ASSET_PRICE = 1e18;      // 1 asset = 1 USD
    uint256 constant COLLATERAL_PRICE = 2000e18; // 1 collateral = 2000 USD
    
    function setUp() public {
        owner = address(this);
        user1 = address(0x1);
        user2 = address(0x2);
        liquidator = address(0x3);
        
        // 部署代币
        asset = new MockERC20("USD Coin", "USDC");
        collateral = new MockERC20("Wrapped Ether", "WETH");
        
        // 部署预言机
        oracle = new SimplePriceOracle();
        oracle.setPrice(address(asset), ASSET_PRICE);
        oracle.setPrice(address(collateral), COLLATERAL_PRICE);
        
        // 部署风险管理器
        riskManager = new RiskManager();
        
        // 部署利率模型
        interestModel = new InterestRateModel();
        
        // 部署主合约
        lend = new MiniLend(
            address(asset),
            address(collateral),
            address(oracle),
            interestModel,
            riskManager
        );
        
        // 给用户铸造测试代币
        asset.mint(user1, 1000000e18);
        collateral.mint(user1, 10000e18);
        asset.mint(user2, 1000000e18);
        collateral.mint(user2, 10000e18);
        asset.mint(liquidator, 1000000e18);
        asset.mint(address(lend),100000000000e18);
        
        // 授权
        vm.startPrank(user1);
        asset.approve(address(lend), type(uint256).max);
        collateral.approve(address(lend), type(uint256).max);
        vm.stopPrank();
        
        vm.startPrank(user2);
        asset.approve(address(lend), type(uint256).max);
        collateral.approve(address(lend), type(uint256).max);
        vm.stopPrank();
        
        vm.prank(liquidator);
        asset.approve(address(lend), type(uint256).max);
    }
    
    // ==================== 基础功能测试 ====================
    
    function testDepositAsset() public {
        vm.prank(user1);
        lend.depositAsset(1000e18);
        
        (uint256 deposited, , , , ) = lend.users(user1);
        assertEq(deposited, 1000e18);
    }
    
    function testDepositCollateral() public {
        vm.prank(user1);
        lend.depositCollateral(100e18);
        
        (, , uint256 collateralAmount, , ) = lend.users(user1);
        assertEq(collateralAmount, 100e18);
    }
    
    function testBorrow() public {
        // 准备：存入抵押品
        vm.prank(user1);
        lend.depositCollateral(100e18); // 100 WETH = 200,000 USD
        
        // 借款：最多可借 200,000 * 75% = 150,000 USDC
        vm.prank(user1);
        lend.borrow(100000e18);
        
        (, uint256 borrowed, , , ) = lend.users(user1);
        assertEq(borrowed, 100000e18);
    }
    
    function testRepay() public {
        // 准备：存入抵押品并借款
        vm.startPrank(user1);
        lend.depositCollateral(100e18);
        lend.borrow(100000e18);
        vm.stopPrank();
        
        // 还款
        vm.prank(user1);
        lend.repay(50000e18);
        
        (, uint256 borrowed, , , ) = lend.users(user1);
        assertEq(borrowed, 50000e18);
    }
    
    // ==================== 边界测试 ====================
    
    function testRevertWhenDepositZero() public {
        vm.prank(user1);
        vm.expectRevert(MiniLend.MiniLend__AmountZero.selector);
        lend.depositAsset(0);
    }
    
    function testRevertWhenBorrowTooMuch() public {
        vm.prank(user1);
        lend.depositCollateral(1e18); // 1 WETH = 2000 USD
        // 最多可借 2000 * 75% = 1500 USDC
        
        vm.prank(user1);
        vm.expectRevert(MiniLend.MiniLend__HealthFactorTooLow.selector);
        lend.borrow(1600e18);
    }
    
    function testRevertWhenWithdrawTooMuchCollateral() public {
        vm.startPrank(user1);
        lend.depositCollateral(100e18);
        lend.borrow(100000e18); // 借100k USDC
        vm.stopPrank();
        
        // 取回过多抵押品会导致健康因子过低
        vm.prank(user1);
        vm.expectRevert(MiniLend.MiniLend__HealthFactorTooLow.selector);
        lend.withdrawCollateral(99e18);
    }
    
    // ==================== 清算测试====================
    
    function testLiquidate() public {
        // 用户1：存入抵押品并借款
        vm.startPrank(user1);
        lend.depositCollateral(100e18); // 100 WETH = 200,000 USD
        lend.borrow(150000e18); // 借150k USDC，接近上限
        vm.stopPrank();
        
        // 模拟价格下跌：抵押品价格从2000跌到1500
        oracle.setPrice(address(collateral), 1500e18);
        
        // 检查是否可清算
        (,uint256 borrowed , uint256 coll, , ) = lend.users(user1);
        assertTrue(
            riskManager.canBeLiquidated(borrowed, coll, ASSET_PRICE, 1500e18),
            "Should be liquidatable"
        );
        
        // 清算人执行清算
        uint256 debtBefore = borrowed;
        uint256 collBefore = coll;
        
        vm.startPrank(liquidator);
        uint256 debtToCover = debtBefore * 5000 / 10000; // 最多清算50%
        lend.liquidate(user1, debtToCover);
        vm.stopPrank();
        
        // 验证状态变化
        (borrowed, , coll, , ) = lend.users(user1);
        assertLt(borrowed, debtBefore, "Debt should decrease");
        assertLt(coll, collBefore, "Collateral should decrease");
    }
    
    function testCannotLiquidateHealthyPosition() public {
        // 用户1：健康状态
        vm.startPrank(user1);
        lend.depositCollateral(100e18);
        lend.borrow(100000e18); // 只借100k，远低于上限
        vm.stopPrank();
        
        // 清算应该失败
        vm.prank(liquidator);
        vm.expectRevert(MiniLend.MiniLend__NotAllowed.selector);
        lend.liquidate(user1, 10000e18);
    }
    
    // ==================== 利息测试 ====================
    
    function testInterestAccrues() public {
        vm.startPrank(user1);
        lend.depositCollateral(10000e18);
        lend.borrow(100000e18);
        vm.stopPrank();
        
        // 模拟时间前进1年
        vm.warp(block.timestamp + 365 days);
        
        // 触发利息计算
        vm.startPrank(user1);
        lend.depositAsset(100000e18);
       (, , uint256 col, , ) = lend.users(user1);
       console.log("col=",col);
        lend.borrow(1e18);
        vm.stopPrank();
        
        (, uint256 borrowed, , , ) = lend.users(user1);
        assertGt(borrowed, 100001e18, "Borrow interest should accrue");
    }
    
    // ==================== 权限测试 ====================
    
    function testPause() public {
        // 非owner不能pause
        vm.prank(user1);
        vm.expectRevert();
        riskManager.setPaused(true);
        
        // owner可以pause
        riskManager.setPaused(true);
        assertTrue(riskManager.paused());
        
        // pause后操作应该revert
        vm.prank(user1);
        vm.expectRevert(MiniLend.MiniLend__Paused.selector);
        lend.depositAsset(100e18);
    }
    
    // ==================== 辅助函数测试 ====================
    
    function testHealthFactor() public {
        vm.startPrank(user1);
        lend.depositCollateral(100e18);
        lend.borrow(100000e18);
        vm.stopPrank();
        
        uint256 hf = lend.healthFactor(user1);
        // 健康因子应该在合理范围内
        assertGt(hf, 0);
        assertLt(hf, type(uint256).max);
    }
    
    function testBorrowLimit() public {
        vm.startPrank(user1);
        lend.depositCollateral(100e18);
        vm.stopPrank();
        
        uint256 limit = lend.borrowLimit(user1);
        // 100 WETH * 2000 * 75% = 150,000 USDC
        assertEq(limit, 150000e18);
    }
    
    // ==================== Fuzz测试 ====================
    
    function testFuzzDepositWithdraw(uint256 amount) public {
        vm.assume(amount > 0 && amount < 1000000e18);
        
        vm.prank(user1);
        lend.depositAsset(amount);
        
        vm.prank(user1);
        lend.withdrawAsset(amount);
        
        (uint256 deposited, , , , ) = lend.users(user1);
        assertEq(deposited, 0);
    }
    
    function testFuzzBorrowRepay(uint256 borrowAmount, uint256 repayAmount) public {
        vm.assume(borrowAmount > 0 && borrowAmount < 150000e18);
        vm.assume(repayAmount > 0 && repayAmount <= borrowAmount);
        
        vm.startPrank(user1);
        lend.depositCollateral(100e18); // 100 WETH
        lend.borrow(borrowAmount);
        vm.stopPrank();
        
        vm.prank(user1);
        lend.repay(repayAmount);
        
        (, uint256 borrowed, , , ) = lend.users(user1);
        assertEq(borrowed, borrowAmount - repayAmount);
    }
    
    // ==================== Invariant测试 ====================
    
    function testInvariantTotalSupplyMatches() public {
        // 总存款应该等于所有用户存款之和
        vm.prank(user1);
        lend.depositAsset(1000e18);
        
        vm.prank(user2);
        lend.depositAsset(2000e18);
        
        uint256 total = lend.totalDeposits();
        (uint256 d1, , , , ) = lend.users(user1);
        (uint256 d2, , , , ) = lend.users(user2);
        
        assertEq(total, d1 + d2);
    }
    
    // ==================== 批量操作测试 ====================
    
    function testMultipleUsers() public {
        // user1存抵押品借钱
        vm.startPrank(user1);
        lend.depositCollateral(100e18);
        lend.borrow(100000e18);
        vm.stopPrank();
        
        // user2存资产赚利息
        vm.prank(user2);
        lend.depositAsset(50000e18);
        
        // 验证系统状态
        assertGt(lend.totalDeposits(), 0);
        assertGt(lend.totalBorrows(), 0);
        assertGt(lend.totalCollateral(), 0);
    }
}