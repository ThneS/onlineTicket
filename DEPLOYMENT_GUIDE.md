# OnlineTicket 部署指南

## 📋 概述

本指南将帮助你部署完整的 OnlineTicket 去中心化门票平台，包括所有核心合约和初始配置。

## 🏗️ 系统架构

```
OnlineTicket 平台
├── PlatformToken (ERC20)    - 平台代币
├── TicketManager (ERC721)   - 门票NFT管理
├── EventManager             - 活动管理
├── TokenSwap (AMM)          - 代币交换
└── Marketplace              - 二级市场
```

## 🛠️ 环境准备

### 1. 安装依赖

```bash
# 安装 Foundry
curl -L https://foundry.paradigm.xyz | bash
foundryup

# 验证安装
forge --version
cast --version
anvil --version
```

### 2. 克隆项目

```bash
git clone <repository-url>
cd onlineTicket
```

### 3. 安装项目依赖

```bash
forge install
```

### 4. 编译合约

```bash
make build
# 或者
forge build
```

### 5. 运行测试

```bash
make test
# 或者
forge test
```

## 🚀 部署选项

### 选项 1: 快速部署 (推荐新手)

```bash
# 1. 启动本地测试网络
anvil

# 2. 快速部署 (新终端)
make deploy-quick

# 3. 运行演示
make demo
```

### 选项 2: 完整部署

```bash
# 启动本地网络
anvil

# 完整部署（包含初始配置和流动性）
make deploy-full
```

### 选项 3: 手动部署

```bash
# 设置环境变量
export PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
export RPC_URL=http://127.0.0.1:8545

# 运行完整部署脚本
forge script script/DeployOnlineTicket.s.sol:DeployOnlineTicket \
    --rpc-url $RPC_URL \
    --private-key $PRIVATE_KEY \
    --broadcast
```

## 📝 部署脚本说明

### 1. DeployOnlineTicket.s.sol

- **功能**: 完整的产品级部署脚本
- **特点**:
  - 按依赖顺序部署所有合约
  - 自动设置权限和参数
  - 可添加初始流动性
  - 完整的部署验证
- **适用**: 生产环境、测试网部署

### 2. QuickDeploy.s.sol

- **功能**: 简化的快速部署脚本
- **特点**:
  - 一键部署所有合约
  - 基本权限设置
  - 最小配置
  - 适合开发调试
- **适用**: 本地开发、快速测试

### 3. ManageContracts.s.sol

- **功能**: 部署后的管理和维护
- **特点**:
  - 权限管理
  - 参数调整
  - 紧急操作
  - 系统状态查询
- **适用**: 运维管理

### 4. DemoScript.s.sol

- **功能**: 完整功能演示
- **特点**:
  - 模拟完整业务流程
  - 创建活动和购买门票
  - 代币交换和二级市场交易
- **适用**: 功能展示、集成测试

## 🔧 网络配置

### 本地开发网络 (Anvil)

```bash
# 启动 Anvil
anvil --host 0.0.0.0 --port 8545

# 默认配置
RPC_URL=http://127.0.0.1:8545
CHAIN_ID=31337
PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
```

### Sepolia 测试网

```bash
# 环境变量
export SEPOLIA_RPC_URL=https://ethereum-sepolia.publicnode.com
export PRIVATE_KEY=你的私钥

# 部署到 Sepolia
make sepolia-deploy
```

### 主网 (谨慎操作)

```bash
# 环境变量
export MAINNET_RPC_URL=https://ethereum.publicnode.com
export PRIVATE_KEY=你的私钥
export ETHERSCAN_API_KEY=你的API密钥

# 部署到主网
forge script script/DeployOnlineTicket.s.sol:DeployOnlineTicket \
    --rpc-url $MAINNET_RPC_URL \
    --private-key $PRIVATE_KEY \
    --broadcast \
    --verify
```

## 📊 部署验证

### 1. 检查合约部署

```bash
# 查看系统状态
make status

# 手动验证
cast code $PLATFORM_TOKEN_ADDRESS --rpc-url $RPC_URL
```

### 2. 验证合约关联

```bash
# 检查 EventManager 是否正确关联 TicketManager
cast call $EVENT_MANAGER_ADDRESS "ticketManager()" --rpc-url $RPC_URL

# 检查权限设置
cast call $TICKET_MANAGER_ADDRESS "authorizedMinters(address)" $EVENT_MANAGER_ADDRESS --rpc-url $RPC_URL
```

### 3. 测试基本功能

```bash
# 运行完整演示
make demo

# 或者手动测试创建活动
cast send $EVENT_MANAGER_ADDRESS \
    "createEvent(string,string,string,string,uint256,uint256,bool)" \
    "Test Event" "Description" "image.jpg" "Venue" \
    $(($(date +%s) + 86400)) $(($(date +%s) + 172800)) false \
    --private-key $PRIVATE_KEY \
    --rpc-url $RPC_URL
```

## 🎛️ 部署后配置

### 1. 设置合约地址

```bash
# 创建 .env 文件
cat > .env << EOF
PLATFORM_TOKEN_ADDRESS=0x...
TICKET_MANAGER_ADDRESS=0x...
EVENT_MANAGER_ADDRESS=0x...
TOKEN_SWAP_ADDRESS=0x...
MARKETPLACE_ADDRESS=0x...
EOF
```

### 2. 权限管理

```bash
# 授权新的主办方
make authorize

# 或者使用脚本
forge script script/ManageContracts.s.sol:ManageContracts \
    --sig "authorizeOrganizer(address)" 0x新主办方地址 \
    --broadcast
```

### 3. 添加流动性

```bash
# 交互式添加流动性
make add-liquidity

# 或者指定数量
PLATFORM_TOKEN_ADDRESS=$TOKEN_ADDRESS \
TOKEN_SWAP_ADDRESS=$SWAP_ADDRESS \
forge script script/ManageContracts.s.sol:ManageContracts \
    --sig "addLiquidity(uint256,uint256)" 100000000000000000000000 1000000000000000000 \
    --broadcast
```

## 🚨 安全检查清单

### 部署前检查

- [ ] 合约代码已审计
- [ ] 测试覆盖率 > 90%
- [ ] 所有测试用例通过
- [ ] 私钥安全存储
- [ ] RPC URL 正确配置

### 部署后检查

- [ ] 所有合约成功部署
- [ ] 合约关联正确设置
- [ ] 权限配置正确
- [ ] 初始参数合理
- [ ] 紧急暂停功能可用

### 运营检查

- [ ] 多签钱包设置 (生产环境)
- [ ] 监控和报警配置
- [ ] 升级策略制定
- [ ] 应急预案准备

## 🔄 常用管理命令

```bash
# 查看系统状态
make status

# 暂停所有合约 (紧急情况)
make pause-all

# 恢复所有合约
make unpause-all

# 更新费率
forge script script/ManageContracts.s.sol:ManageContracts \
    --sig "updateFeeRates(uint256,uint256,uint256,uint256)" 500 250 30 250 \
    --broadcast

# 铸造代币
forge script script/ManageContracts.s.sol:ManageContracts \
    --sig "mintTokens(address,uint256)" 0x接收地址 1000000000000000000000 \
    --broadcast
```

## 📈 监控和维护

### 1. 关键指标监控

- 代币总供应量和分布
- 流动性池储备量
- 平台手续费收入
- 活跃用户数量
- 交易量和频次

### 2. 日常维护任务

- 检查合约状态
- 监控异常交易
- 更新白名单
- 处理用户反馈
- 备份重要数据

### 3. 升级和优化

- 合约功能升级
- 参数优化调整
- 性能监控分析
- 安全漏洞修复

## 🆘 故障排除

### 常见问题

1. **部署失败**

   - 检查网络连接
   - 验证私钥和余额
   - 确认合约编译成功

2. **权限错误**

   - 确认合约所有者
   - 检查授权状态
   - 验证函数调用者

3. **交易失败**

   - 检查 Gas 限制
   - 验证参数格式
   - 确认合约状态

4. **功能异常**
   - 查看事件日志
   - 检查合约状态
   - 验证依赖关系

### 获取帮助

- 查看测试用例了解预期行为
- 检查合约事件和错误消息
- 使用 `cast` 工具调试交易
- 参考项目文档和代码注释

## 📚 更多资源

- [Foundry 文档](https://book.getfoundry.sh/)
- [Solidity 文档](https://docs.soliditylang.org/)
- [OpenZeppelin 合约](https://docs.openzeppelin.com/contracts/)
- [以太坊开发文档](https://ethereum.org/developers/)

---

🎉 **祝你部署成功！** 如有问题，请参考故障排除部分或查看项目文档。
