# MiniLend - 简化版去中心化借贷协议

## 项目概述

MiniLend 是一个简化版去中心化借贷协议，实现了资产存款、抵押借款、动态利率、清算等核心 DeFi 借贷功能。集成 Chainlink 价格预言机，已在 Sepolia 测试链部署验证。

## 核心功能

### 1. 存款与取款
- 存入资产赚取存款利息
- 支持随时取回（需满足流动性条件）
- 利息基于利用率动态计算并自动累积

### 2. 抵押与借款
- 使用抵押资产（如 BTC）作为担保借出资产（如 ETH）
- 基于抵押品价值和 LTV 计算可借额度
- 还款时优先覆盖利息，再偿还本金

### 3. 动态利率模型
- 分段利率曲线（利用率 <=80% 和 >80% 两段斜率）
- 类似 Aave/Compound 的 kinked 利率模型
- 存款利率 = 借款利率 × 利用率 × (1 - 储备因子)

### 4. 风险管理
- LTV（贷款价值比）控制借款上限（默认 75%）
- 清算阈值触发清算（默认 80%）
- 健康因子实时监控
- 协议支持紧急暂停

### 5. 清算机制
- 健康因子低于阈值时触发清算
- 清算人可获得 5% 清算奖励
- 单次最多清算 50% 债务
- 支持批量查询可清算用户

## 技术架构

### 合约结构

```
MiniLend/
├── src/
│   ├── MiniLend.sol              # 主借贷合约
│   ├── RiskManager.sol           # 风险管理模块（LTV/清算参数）
│   ├── InterestRateModel.sol     # 分段利率模型
│   ├── ChainlinkPriceOracle.sol  # Chainlink 价格预言机
│   ├── Asset.sol                 # 借贷资产代币（ETH）
│   └── Collateral.sol            # 抵押资产代币（BTC）
├── test/
│   ├── MiniLend.t.sol            # 主合约综合测试（含模糊测试）
│   └── RiskManager.t.sol         # 风险管理单元测试
└── script/
    ├── Deploy.s.sol              # 完整部署脚本
    └── interactions/
        ├── FullFlow.s.sol        # 全流程交互脚本
        └── Liquidate.s.sol       # 清算执行脚本
```

### 技术栈

- **Solidity**: ^0.8.20
- **框架**: Foundry (forge, cast, anvil)
- **依赖**: OpenZeppelin（Ownable、ReentrancyGuard、SafeERC20）
- **预言机**: Chainlink AggregatorV3Interface（含价格时效检查）
- **前端**: Vite + ethers.js（轻量级交互面板）
- **测试**: DSTest + 模糊测试

## 核心合约详解

### MiniLend — 主借贷合约

中央调度合约，管理用户存款、借款、抵押和清算业务：

- 用户状态管理：`deposited`、`borrowed`、`collateral`、`depositLastUpdate`、`borrowLastUpdate`
- 借款人列表：`borrowerList` 数组 + `hasBorrowed` 映射，支持遍历查询可清算用户
- 所有存款/借款操作前自动调用利息累积
- 借款时必须通过 RiskManager 的 LTV 检查
- 取回抵押品时检查健康因子
- 公开事件：`Deposited`、`Withdrawn`、`Borrowed`、`Repaid`、`Liquidated`

### RiskManager — 风险管理器

独立的参数管理模块（均为 basis points）：

| 参数 | 默认值 | 说明 |
|---|---|---|
| LTV | 7500 (75%) | 最大贷款价值比 |
| liquidationThreshold | 8000 (80%) | 清算阈值 |
| liquidationBonus | 500 (5%) | 清算奖励比例 |
| closeFactor | 5000 (50%) | 单次清算比例上限 |

功能：判断借款是否允许、判断仓位是否可清算、计算清算扣押数量、紧急暂停、价格喂价注册。

### InterestRateModel — 利率模型

kinked 利率曲线（精度 1e18）：

- 利用率 <= 80%：`borrowRate = BASE_RATE + SLOPE1 × utilization / 1e18`
- 利用率 > 80%：`borrowRate = BASE_RATE + SLOPE1 + SLOPE2 × (utilization - OPTIMAL) / (1e18 - OPTIMAL)`
- 存款利率：`borrowRate × utilization / 1e18 × (10000 - RESERVE_FACTOR) / 10000`

| 参数 | 默认值 | 说明 |
|---|---|---|
| BASE_RATE | 2% | 基础借款利率 |
| SLOPE1 | 10% | 低利用率斜率 |
| SLOPE2 | 50% | 高利用率斜率 |
| OPTIMAL_UTIL | 80% | 最优利用率 |
| RESERVE_FACTOR | 10% | 协议储备因子 |

### ChainlinkPriceOracle — 价格预言机

通过 RiskManager 的 `priceFeeds` 映射查询代币对应的 Chainlink 聚合器地址，调用 `latestRoundData()` 获取价格：

- 价格过期检查（超过 1 小时回退）
- 自动精度归一化到 18 位小数
- 价格小于等于 0 时回退

## 快速开始

### 环境要求

- Foundry (forge, cast, anvil)
- Git

### 安装依赖

```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup

git clone <your-repo-url>
cd MiniLend

forge install
```

### 运行测试

```bash
# 运行所有测试
forge test

# 运行特定测试
forge test --match-test testDepositAsset -vvv

# 模糊测试
forge test --match-test testFuzz -vvv
```

### 部署合约

```bash
forge script script/Deploy.s.sol --fork-url <rpc-url> --broadcast
```

### 交互脚本

```bash
# 完整借贷流程
forge script script/interactions/FullFlow.s.sol --fork-url http://localhost:8545 --broadcast

# 清算
forge script script/interactions/Liquidate.s.sol --fork-url http://localhost:8545 --broadcast
```

## 📈 事件监控

项目包含JavaScript事件监控脚本，可以实时监听链上事件：

```javascript
// 启动事件监听
node scripts/eventMonitor.js
```

监控的事件包括：
- 存款/取款事件
- 抵押/借款事件
- 还款事件
- 清算事件（重点监控）
- 风险参数更新

## 前端

基于 Vite + ethers.js 的轻量级交互面板，提供：

- 钱包连接与实时仪表盘
- 存款/取款、抵押/借款、还款操作
- 健康因子与借款限额可视化
- 交易记录本地持久化
- 数据分析图表（Chart.js）
- 清算机器人面板（批量扫描 + 一键清算）
- 暗色/亮色主题切换

```bash
cd frontend
npm install
npm run dev
```

## 安全特性

1. **重入防护**: OpenZeppelin ReentrancyGuard
2. **访问控制**: 关键参数仅限合约所有者
3. **价格安全**: Chainlink 预言机含过期校验和零值保护
4. **紧急暂停**: RiskManager 一键暂停协议
5. **参数校验**: RiskManager 参数更新有合法性约束
6. **数学安全**: OpenZeppelin Math + SafeERC20

## 测试覆盖

| 类型 | 说明 |
|---|---|
| 单元测试 | 每项功能的独立验证 |
| 边界测试 | 零金额、超额等异常场景 |
| 清算测试 | 健康/不健康仓位清算逻辑 |
| 利息测试 | 时间跳跃后的利息累积验证 |
| 权限测试 | 暂停/恢复功能权限控制 |
| 多用户测试 | 多用户共存场景 |
| 不变性测试 | 系统总存款 = 各用户存款之和 |
| 模糊测试 | 随机存款/取款和借款/还款 |

## 注意事项

- 本项目仅供学习参考，未经专业审计
- 请勿在生产环境使用
- 代码中 `addBorrowBalanceForTest` 为测试辅助函数，生产环境应移除
