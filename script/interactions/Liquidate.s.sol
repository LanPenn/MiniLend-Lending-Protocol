// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../../src/MiniLend.sol";
import "../../src/SimplePriceOracle.sol";

contract Liquidate is Script {

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");

        address lendAddr = vm.envAddress("LEND");
        address oracleAddr = vm.envAddress("ORACLE");
        address collateralAddr = vm.envAddress("COLLATERAL");

        MiniLend lend = MiniLend(lendAddr);
        SimplePriceOracle oracle = SimplePriceOracle(oracleAddr);

        address targetUser = vm.envAddress("TARGET");

        vm.startBroadcast(pk);

        //  降低抵押价格 → 触发清算
        oracle.setPrice(collateralAddr, 1000e18);

        // 清算 500 USDC
        lend.liquidate(targetUser, 500e18);

        vm.stopBroadcast();
    }
}