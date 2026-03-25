// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/RiskManager.sol";

contract RiskManagerTest is Test {
    RiskManager public riskManager;
    
    function setUp() public {
        riskManager = new RiskManager();
    }
    
    function testCanBorrow() view public {
        // 抵押品价值 = 100 * 2000 = 200,000
        // 借款价值 = 150,000
        // LTV = 75%, 150,000 <= 200,000 * 75% = 150,000 
        assertTrue(riskManager.canBorrow(150000e18, 100e18, 1e18, 2000e18));
        
        // 借款过多
        assertFalse(riskManager.canBorrow(160000e18, 100e18, 1e18, 2000e18));
    }
    
    function testCanBeLiquidated() view public {
        // 抵押品价值 = 100 * 2000 = 200,000
        // 借款价值 = 170,000
        // 清算阈值 = 80%, 170,000 > 200,000 * 80% = 160,000 
        assertTrue(riskManager.canBeLiquidated(170000e18, 100e18, 1e18, 2000e18));
        
        // 健康状态
        assertFalse(riskManager.canBeLiquidated(150000e18, 100e18, 1e18, 2000e18));
    }
    
    function testCalculateLiquidationAmount()view  public {
        // debtToCover = 1000, assetPrice = 1, collPrice = 2000, bonus = 5%
        // 清算人应获得: 1000 * 1 * (10000 + 500) / (2000 * 10000) = 0.525
        uint256 amount = riskManager.calculateLiquidationAmount(1000e18, 1e18, 2000e18);
        assertEq(amount, 0.525e18);
    }
    
    function testUpdateRiskParams() public {
        riskManager.updateRiskParams(8000, 8500, 1000, 6000);
        
        assertEq(riskManager.LTV(), 8000);
        assertEq(riskManager.liquidationThreshold(), 8500);
        assertEq(riskManager.liquidation_bonus(), 1000);
        assertEq(riskManager.closeFactor(), 6000);
    }
    
    function testRevertInvalidRiskParams() public {
        // LTV不能超过9000
        vm.expectRevert();
        riskManager.updateRiskParams(9500, 9500, 500, 5000);
        
        // 清算阈值必须 >= LTV
        vm.expectRevert();
        riskManager.updateRiskParams(8000, 7500, 500, 5000);
    }
}