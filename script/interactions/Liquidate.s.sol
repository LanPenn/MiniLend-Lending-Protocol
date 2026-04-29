// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../../src/MiniLend.sol";

contract Liquidate is Script {

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");

        address lendAddr = vm.envAddress("LEND");
        address collateralAddr = vm.envAddress("COLLATERAL");

        MiniLend lend = MiniLend(lendAddr);

        address targetUser = vm.envAddress("TARGET");

        vm.startBroadcast(pk);

        // 清算 500 USDC
        lend.liquidate(targetUser, 500e18);

        vm.stopBroadcast();
    }
}
