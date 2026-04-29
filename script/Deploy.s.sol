// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/MiniLend.sol";
import "../src/InterestRateModel.sol";
import "../src/RiskManager.sol";
import "../src/ChainlinkPriceOracle.sol";
import "../src/Asset.sol";
import "../src/Collateral.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        console.log("Deploying tokens...");
        Asset asset = new Asset("Ethereum", "ETH");
        Collateral collateral = new Collateral("Bitcoin", "BTC");
        console.log("Asset (ETH):", address(asset));
        console.log("Collateral (BTC):", address(collateral));

        console.log("Deploying risk manager...");
        RiskManager riskManager = new RiskManager();
        console.log("RiskManager:", address(riskManager));

        console.log("Deploying oracle (Chainlink)...");
        ChainlinkPriceOracle oracle = new ChainlinkPriceOracle(riskManager);
        console.log("Oracle:", address(oracle));

        console.log("Deploying interest model...");
        InterestRateModel interestModel = new InterestRateModel();
        console.log("InterestModel:", address(interestModel));

        console.log("Deploying MiniLend...");
        MiniLend lend = new MiniLend(
            address(asset),
            address(collateral),
            address(oracle),
            interestModel,
            riskManager
        );
        console.log("MiniLend:", address(lend));

        asset.mint(msg.sender, 1000000e18);
        collateral.mint(msg.sender, 10000e18);
        asset.mint(address(lend), 100000000e18);

        vm.stopBroadcast();

        console.log("=== Deployment Complete ===");
    }
}