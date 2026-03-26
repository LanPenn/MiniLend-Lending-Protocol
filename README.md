# MiniLend - 简化版去中心化借贷协议

## 📋 项目概述

MiniLend 是一个简化的去中心化借贷协议，是我学习 DeFi 借贷协议过程中的一个练习项目，还有许多不完善的地方，欢迎交流讨论。该项目实现了基本的借贷功能，包括资产存款、抵押、借款、还款和清算等核心功能。

## 🚀 核心功能

### 1. **存款与取款**
- 用户可以存入资产赚取利息
- 支持随时取回存款（需满足流动性条件）

### 2. **抵押与借款**
- 使用抵押品（如WETH）作为担保
- 基于抵押品价值计算可借款额度
- 动态利率模型计算借款利息

### 3. **风险管理**
- 贷款价值比（LTV）控制
- 清算阈值和清算奖励机制
- 健康因子监控

### 4. **清算机制**
- 当用户健康因子低于阈值时触发清算
- 清算人可获得清算奖励
- 保护协议免受坏账风险

### 5. **利率模型**
- 基于利用率的动态利率计算
- 类似Aave/Compound的利率曲线
- 存款利率和借款利率分离

## 🏗️ 技术架构

### 合约结构
```
MiniLend/
├── src/
│   ├── MiniLend.sol          # 主合约
│   ├── InterestRateModel.sol # 利率模型
│   ├── RiskManager.sol       # 风险管理
│   ├── SimplePriceOracle.sol # 简单预言机
│   ├── Asset.sol             # 借贷资产（USDC）
│   └── Collateral.sol        # 抵押资产（WETH）
├── test/
│   ├── MiniLendTest.sol      # 主合约测试
│   └── RiskManagerTest.sol   # 风险管理测试
└── script/interactions
           ├── FullFlow.sol          # 完整流程交互
           └── Liquidate.sol         # 清算脚本
    ├── DeployScript.sol      # 部署脚本
    └── monitor.js            # 事件监控脚本
```

### 技术栈
- **Solidity**: ^0.8.13
- **OpenZeppelin**: 访问控制、安全数学、重入防护
- **Foundry**: 开发、测试和部署框架
- **Forge/anvil**: 智能合约开发工具
- **ethers.js**: 事件监控和前端交互

## ⚙️ 核心机制

### 风险管理
- 贷款价值比（LTV）控制借款上限
- 清算阈值触发风险位置清算
- 清算奖励激励清算人参与
- 清算因子限制单次清算比例

### 利率模型
- 基于利用率的动态利率计算
- 分段利率曲线（类似主流借贷协议）
- 存款利率与借款利率联动
- 协议储备因子提取部分收益

## 🛠️ 快速开始

### 环境要求
- Node.js 16+
- Foundry (forge, cast, anvil)
- Git

### 安装依赖
```bash
# 安装 Foundry
curl -L https://foundry.paradigm.xyz | bash
foundryup

# 克隆项目
git clone https://github.com/LanPenn/MiniLend-Lending-Protocol.git
cd MiniLend-Lending-Protocol

# 安装依赖
forge install foundry-rs/forge-std
forge install OpenZeppelin/openzeppelin-contracts
```

### 运行测试
```bash
# 运行所有测试
forge test -vvv

# 运行特定测试
forge test --match-test testDepositAsset
forge test --match-test testLiquidate


### 部署合约
```bash

# 新建终端启动anvil
anvil
# 设置环境变量
export PRIVATE_KEY=<your-private-key>
export RPC_URL=<your-rpc-url>

# 部署到本地网络
forge script script/Deploy.s.sol --fork-url http://localhost:8545 --broadcast

# 部署到测试网
forge script script/Deploy.s.sol --rpc-url $RPC_URL --broadcast
```

### 交互示例
```bash
# 运行完整流程
export Lend=<your-address>
export ASSET=<your-address>
export COLLATERAL=<your-address>
export ORACLE=<your-address>

forge script script/interactions/FullFlow.s.sol --fork-url http://localhost:8545 --broadcast

# 执行清算
forge script script/interactions/Liquidate.s.sol --fork-url http://localhost:8545 --broadcast
```

## 📈 事件监控

项目包含JavaScript事件监控脚本，可以实时监听链上事件：

```javascript
// 启动事件监听
npm install ethers
node script/monitor.js
```

监控的事件包括：
- 存款/取款事件
- 抵押/借款事件
- 还款事件
- 清算事件（重点监控）
- 风险参数更新

## 🔒 安全特性

1. **重入攻击防护**: 使用OpenZeppelin的ReentrancyGuard
2. **数学安全**: 使用SafeMath和Math库
3. **访问控制**: 关键功能仅限合约所有者
4. **输入验证**: 所有函数都有参数验证
5. **紧急暂停**: 风险管理器支持紧急暂停功能

## 🧪 测试覆盖

项目包含全面的测试套件：
- **单元测试**: 每个合约的独立功能测试
- **集成测试**: 合约间交互测试
- **边界测试**: 极端情况测试
- **模糊测试**: 随机输入测试
- **不变性测试**: 系统状态一致性验证

## ⚠️ 注意事项

- 本项目为学习用途，未经充分审计
- 请勿在生产环境使用
- 代码仅供参考和学习Web3开发
