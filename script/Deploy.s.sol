// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/MiniLend.sol";
import "../src/InterestRateModel.sol";
import "../src/RiskManager.sol";
import "../src/SimplePriceOracle.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../src/Asset.sol";
import "../src/Collateral.sol";



contract DeployScript is Script {
    MiniLend public lend;
    Asset public asset;
    Collateral public collateral;
    SimplePriceOracle public oracle;
    InterestRateModel public interestModel;
    RiskManager public riskManager;
    
    // 价格配置
    uint256 constant ASSET_PRICE = 1e18;        // 1 USDC = 1 USD
    uint256 constant COLLATERAL_PRICE = 2000e18; // 1 WETH = 2000 USD
    
    function run() external {
        // 开始广播交易
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        
        // 1. 部署代币
        console.log("Deploying tokens...");
        asset = new  Asset("USD Coin", "USDC");
        collateral = new Collateral("Wrapped Ether", "WETH");
        
        // 2. 部署预言机
        console.log("Deploying oracle...");
        oracle = new SimplePriceOracle();
        oracle.setPrice(address(asset), ASSET_PRICE);
        oracle.setPrice(address(collateral), COLLATERAL_PRICE);
        
        // 3. 部署风险管理器
        console.log("Deploying risk manager...");
        riskManager = new RiskManager();
        
        // 可选：调整风险参数
        // riskManager.updateRiskParams(7500, 8000, 500, 5000);
        
        // 4. 部署利率模型
        console.log("Deploying interest rate model...");
        interestModel = new InterestRateModel();
        
        // 5. 部署主合约
        console.log("Deploying MiniLend...");
        lend = new MiniLend(
            address(asset),
            address(collateral),
            address(oracle),
            interestModel,
            riskManager
        );
        
        // 6. 给部署者铸造测试代币
        console.log("Minting test tokens...");
        asset.mint(msg.sender, 1000000e18);     // 100万 USDC
        collateral.mint(msg.sender, 10000e18);   // 1万 WETH
        asset.mint(address(lend),1000000000e18); //合约初始流动性
        
        vm.stopBroadcast();
        
        // 输出部署信息
        console.log("=== Deployment Complete ===");
        console.log("Asset (USDC):", address(asset));
        console.log("Collateral (WETH):", address(collateral));
        console.log("Oracle:", address(oracle));
        console.log("RiskManager:", address(riskManager));
        console.log("InterestRateModel:", address(interestModel));
        console.log("MiniLend:", address(lend));
        console.log("==========================");
        
        // 保存地址到文件（方便后续交互）
        _saveAddresses();
    }
    
    function _saveAddresses() internal {
        string memory output = string(abi.encodePacked(
            "MiniLend Address: ", vm.toString(address(lend)), "\n",
            "USDC Address: ", vm.toString(address(asset)), "\n",
            "WETH Address: ", vm.toString(address(collateral)), "\n",
            "Oracle Address: ", vm.toString(address(oracle)), "\n",
            "RiskManager Address: ", vm.toString(address(riskManager)), "\n",
            "InterestRateModel Address: ", vm.toString(address(interestModel))
        ));
        
        vm.writeFile("./deployed_addresses.txt", output);
        console.log("Addresses saved to deployed_addresses.txt");
    }
}