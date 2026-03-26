const { ethers } = require("ethers");

// RPC（用你自己的）
const RPC_URL = "http://127.0.0.1:8545"; // 或 sepolia
const provider = new ethers.JsonRpcProvider(RPC_URL);

//  合约地址
const CONTRACT_ADDRESS = "你的合约地址";

//  ABI（只放事件即可）
const ABI = [
    "event Deposited(address indexed user, uint256 amount, uint256 time)",
    "event Withdrawn(address indexed user, uint256 amount, uint256 time)",
    "event DepositCollateral(address indexed user, uint256 collateral, uint256 time)",
    "event WithdrawCollateral(address indexed user, uint256 collateral, uint256 time)",
    "event Borrowed(address indexed user, uint256 amount, uint256 time)",
    "event Repaid(address indexed user, uint256 amount, uint256 time)",
    "event Liquidated(address indexed user, address indexed liquidator, uint256 repayAmount, uint256 liquidate, uint256 time)",
    "event RiskParamsUpdated(uint256 newMaxLTV, uint256 newLiquidationThreshold, uint256 newLiquidationBonus, uint256 newCloseFactor)"
];

//  创建合约实例
const contract = new ethers.Contract(CONTRACT_ADDRESS, ABI, provider);

console.log(" 开始监听链上事件...");

//  风控参数（可调整）
const LARGE_AMOUNT = ethers.parseUnits("1000", 18); // 大额阈值

//  监听事件============
// 存款
contract.on("Deposited", (user, amount, time) => {
    console.log(` 存款: ${user} ${ethers.formatUnits(amount, 18)}`);

    if (amount > LARGE_AMOUNT) {
        console.log(` 大额存款预警: ${user}`);
    }
});

// 提现
contract.on("Withdrawn", (user, amount, time) => {
    console.log(` 提现: ${user} ${ethers.formatUnits(amount, 18)}`);

    if (amount > LARGE_AMOUNT) {
        console.log(` 大额提现风险: ${user}`);
    }
});

// 抵押
contract.on("DepositCollateral", (user, collateral, time) => {
    console.log(` 抵押: ${user} ${ethers.formatUnits(collateral, 18)}`);
});

// 借款
contract.on("Borrowed", (user, amount, time) => {
    console.log(`借款: ${user} ${ethers.formatUnits(amount, 18)}`);

    if (amount > LARGE_AMOUNT) {
        console.log(` 大额借款: ${user}`);
    }
});

// 还款
contract.on("Repaid", (user, amount, time) => {
    console.log(` 还款: ${user} ${ethers.formatUnits(amount, 18)}`);
});

// 清算
contract.on("Liquidated", (user, liquidator, repayAmount, liquidate, time) => {
    console.log(` 清算发生:`);
    console.log(`   用户: ${user}`);
    console.log(`   清算人: ${liquidator}`);
    console.log(`   偿还: ${ethers.formatUnits(repayAmount, 18)}`);
    console.log(`   被清算抵押: ${ethers.formatUnits(liquidate, 18)}`);

    console.log(` 风险账户已被清算`);
});

// 风险参数更新
contract.on("RiskParamsUpdated", (ltv, threshold, bonus, closeFactor) => {
    console.log(`风控参数更新:`);
    console.log(`   LTV: ${ltv}`);
    console.log(`   清算阈值: ${threshold}`);
    console.log(`   清算奖励: ${bonus}`);
    console.log(`   closeFactor: ${closeFactor}`);

    console.log(` 系统风险模型已改变！`);
});
