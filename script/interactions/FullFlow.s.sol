// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../../src/MiniLend.sol";
import "../../src/Collateral.sol";
import "../../src/Asset.sol";
import "../../src/SimplePriceOracle.sol";

contract FullFlow is Script {

    function run() external {
        //  读取环境变量
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        address lendAddr = vm.envAddress("LEND");
        address assetAddr = vm.envAddress("ASSET");
        address collateralAddr = vm.envAddress("COLLATERAL");
        address oracleAddr = vm.envAddress("ORACLE");

        // 实例化合约
        MiniLend lend = MiniLend(lendAddr);
        Asset asset = Asset(assetAddr);
        Collateral collateral = Collateral(collateralAddr);
        SimplePriceOracle oracle = SimplePriceOracle(oracleAddr);

        //  开始广播交易
        vm.startBroadcast(deployerPrivateKey);
        address user = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266; // 当前广播账户
        console.log(user);

        // 模拟预言机设置价格
        console.log("Step1: Setting prices");
        oracle.setPrice(assetAddr, 1e18);       // USDC = $1
        oracle.setPrice(collateralAddr, 2000e18); // ETH = $2000
        console.log("Prices set");

        // Mint 资产给当前账户
        console.log("Step2: Minting tokens to user");
        asset.mint(user, 10000e18);       // 10000 USDC
        collateral.mint(user, 10e18);     // 10 ETH
        console.log("Tokens minted");

        // Approve Lend 合约
        console.log("Step3: Approving tokens to MiniLend");
        asset.approve(lendAddr, type(uint256).max);
        collateral.approve(lendAddr, type(uint256).max);
        console.log("Approved");

        // 存款（提供流动性）
        console.log("Step4: Depositing Asset (USDC)");
        uint256 balance = asset.balanceOf(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266);
        console.log(balance);
        lend.depositAsset(5000e18); // 存 5000 USDC
        console.log("Deposited asset");

        // 抵押 Collateral
        console.log("Step5: Depositing Collateral (ETH)");
        lend.depositCollateral(5e18); // 抵押 5 ETH
        console.log("Deposited collateral");

        // 借款
        console.log("Step6: Borrowing 2000 USDC");
        lend.borrow(2000e18);
        console.log("Borrowed");

        // 查询健康因子
        uint256 hf = lend.healthFactor(user);
        console.log("Health Factor:", hf);

        // 偿还部分借款
        console.log("Step8: Repaying 1000 USDC");
        lend.repay(1000e18);
        console.log("Repaid");

        vm.stopBroadcast();
    }
}
