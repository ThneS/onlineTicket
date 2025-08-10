# OnlineTicket 🎫

基于区块链的去中心化门票管理平台，构建安全、透明、可验证的链上票务生态系统。

## 🌟 特性

- **🔐 安全透明**: 基于区块链的门票发行与管理，防伪造、防篡改
- **💱 二级市场**: 支持门票安全转让与交易，平台收取合理手续费
- **🪙 平台代币**: 原生代币支付体系，激励用户参与生态建设
- **📱 自有钱包**: 内置钱包系统，简化用户体验
- **🔍 实时验证**: 线下核销系统，快速验证门票真伪

## 🎯 项目目标

构建一个完整的链上门票生态系统，包括：

- 门票 NFT 的发行、交易、验证全流程
- 平台代币经济体系
- 用户友好的钱包与交互界面
- 活动组织者管理后台
- 线下验票与核销系统

## 🏗️ 系统架构

### 1. 智能合约层 (Smart Contracts)

#### 核心合约

```
src/
├── TicketManager.sol      # 门票NFT合约 (ERC721)
├── EventManager.sol       # 活动管理合约
├── Marketplace.sol        # 交易市场合约
├── PlatformToken.sol      # 平台代币合约 (ERC20)
└── TokenSwap.sol          # 代币互换合约
```

- **TicketManager.sol**: 基于 ERC721 标准的门票 NFT

  - 绑定活动信息、座位、价格等元数据
  - 支持验证状态管理和转移控制
  - 防重复使用和伪造机制

- **EventManager.sol**: 活动生命周期管理

  - 创建活动、配置参数（时间、地点、票种）
  - 与门票合约集成，控制发行权限
  - 活动状态管理（预售、正式销售、结束）

- **Marketplace.sol**: 门票交易市场

  - 一级市场发行（Primary Sales）
  - 二级市场交易（Secondary Market）
  - 平台手续费管理
  - 支持 ETH 和平台代币支付

- **PlatformToken.sol**: 平台原生代币

  - ERC20 标准代币实现
  - 激励机制和分发策略
  - 治理功能预留接口

- **TokenSwap.sol**: 代币互换合约
  - 与其他 ERC20 代币的兑换功能
  - 流动性池管理
  - 价格预言机集成
  - 滑点保护机制

### 2. 前端应用层

#### 推荐技术栈

- **前端框架**: React
- **区块链交互**: viem
- **样式**: Tailwind CSS

#### 用户端

- **活动浏览**: 活动列表、筛选、详情展示
- **门票购买**: 支付流程、钱包连接、交易确认
- **个人中心**: 持有门票管理、交易历史
- **二级市场**: 门票转售、购买他人门票
- **代币互换**: 平台代币与其他代币的兑换功能

#### 组织者端

- **活动创建**: 活动信息配置、票种设置
- **销售管理**: 实时销售数据、库存管理
- **数据分析**: 销售报表、用户画像分析

#### 内置钱包系统

- **Web 钱包**: 浏览器端钱包管理
- **移动端 SDK**: 移动应用钱包集成
- **私钥管理**: 多种托管策略（自托管/MPC/社交恢复）

### 3. 后端服务层

- **数据同步服务**: 监听区块链事件，同步到数据库
- **API 服务**: 提供 REST API 接口
- **验票服务**: 线下核销 API 接口
- **用户管理**: 身份认证、钱包绑定管理

### 4. 验证系统

- **二维码生成**: 基于门票信息生成唯一二维码
- **快速验票**: 扫码验证门票有效性
- **防重复使用**: 区块链状态确保门票唯一性

## 💱 代币互换系统设计

### 核心功能需求

#### 1. **自动做市商 (AMM) 机制**

- **恒定乘积公式**: 实现类似 Uniswap 的 x\*y=k 算法
- **流动性池管理**: 支持用户添加/移除流动性
- **手续费分配**: 交易手续费分配给流动性提供者
- **滑点保护**: 防止大额交易造成价格冲击

#### 2. **支持的代币类型**

- **主流代币**: USDT, USDC, DAI, ETH
- **平台代币**: 原生平台代币
- **扩展支持**: 可配置添加其他 ERC20 代币

#### 3. **价格发现机制**

- **链上价格**: 基于 AMM 池子的实时价格
- **预言机集成**: Chainlink 价格预言机作为参考
- **价格保护**: 防止价格操纵和闪电贷攻击

#### 4. **流动性激励**

- **LP 代币**: 流动性提供者获得 LP 代币证明
- **挖矿奖励**: 为流动性提供者分发平台代币奖励
- **锁仓机制**: 支持时间锁定以获得更高收益

### 技术实现方案

#### 智能合约架构

```solidity
// 核心互换合约
contract TokenSwap {
    // AMM核心逻辑
    function swapExactTokensForTokens() external;
    function addLiquidity() external;
    function removeLiquidity() external;

    // 价格查询
    function getAmountOut() external view returns (uint);
    function getReserves() external view returns (uint, uint);
}

// 流动性奖励合约
contract LiquidityMining {
    function stake() external;
    function unstake() external;
    function claimRewards() external;
}

// 价格预言机集成
contract PriceOracle {
    function getPrice() external view returns (uint);
    function updatePrice() external;
}
```

#### 前端集成功能

- **交易界面**: 直观的代币选择和数量输入
- **价格显示**: 实时汇率和预估收到数量
- **滑点设置**: 用户可调节滑点容忍度
- **流动性管理**: LP 添加/移除界面
- **收益展示**: 流动性挖矿收益统计

#### 安全考虑

- **重入保护**: 防止重入攻击
- **授权检查**: 代币授权额度管理
- **最小流动性**: 防止流动性枯竭
- **紧急暂停**: 管理员紧急暂停功能

### 集成第三方 DEX

#### Uniswap V3 集成

- **路由优化**: 自动寻找最优交易路径
- **集中流动性**: 支持 V3 的价格区间流动性
- **手续费等级**: 0.05%, 0.3%, 1%等不同费率池

#### 1inch 聚合器集成

- **最优价格**: 自动比较多个 DEX 价格
- **智能路由**: 拆分订单获得最佳执行价格
- **Gas 优化**: 减少交易成本

### 业务场景应用

1. **用户购票场景**

   - 用户持有 USDT → 兑换平台代币 → 购买门票
   - 享受平台代币支付折扣

2. **活动组织者场景**

   - 收到的平台代币 → 兑换稳定币
   - 降低代币价格波动风险

3. **流动性提供者场景**

   - 提供 USDT-平台代币流动性
   - 获得交易手续费 + 挖矿奖励

4. **套利机会**
   - 价格差异套利
   - 促进价格发现和市场效率

## � 开发路线图

### 📅 阶段一：智能合约开发 (Week 1-3)

**目标**: 完成核心智能合约开发与测试

**任务清单**:

- [ ] **门票 NFT 合约** (`TicketManager.sol`)
  - ERC721 标准实现
  - 元数据管理 (活动、座位、价格)
  - 转移控制与验证状态
- [ ] **活动管理合约** (`EventManager.sol`)
  - 活动创建与配置
  - 权限管理
  - 状态生命周期
- [ ] **交易市场合约** (`Marketplace.sol`)
  - 一级市场发行逻辑
  - 二级市场交易
  - 手续费分成机制
- [ ] **代币互换合约** (`TokenSwap.sol`)
  - AMM 自动做市商机制
  - 流动性池管理
  - 价格预言机集成
- [ ] **合约部署与测试**
  - Foundry 测试框架集成
  - 本地网络 / 测试网部署
  - 100% 测试覆盖率

**交付物**: 完整的智能合约套件 + 测试用例

---

### 💰 阶段二：平台代币与钱包 (Week 3-4)

**目标**: 完成平台代币设计与基础钱包功能

**任务清单**:

- [ ] **平台代币设计** (`PlatformToken.sol`)
  - ERC20 标准实现
  - 代币经济模型设计
  - 激励机制与分发策略
- [ ] **基础钱包开发**
  - Web 钱包核心功能
  - 钱包连接与交易发送
  - 门票购买代币支付集成
- [ ] **代币分发系统**
  - Faucet 合约开发
  - 初始分发策略实施

**交付物**: 平台代币合约 + 基础钱包功能

---

### 🎨 阶段三：前端界面开发 (Week 4-6)

**目标**: 完成用户端和管理端界面

**任务清单**:

- [ ] **用户端界面**
  - 活动浏览与筛选页面
  - 门票购买流程界面
  - 个人中心与门票管理
  - 钱包连接与交易确认
  - 代币互换交易界面
- [ ] **组织者后台**
  - 活动创建与管理界面
  - 销售数据统计面板
  - 门票核销管理
- [ ] **核销系统前端**
  - 二维码生成器
  - 验票扫码界面

**交付物**: 完整的前端应用（React + viem + Tailwind CSS）

---

### 🔗 阶段四：后端服务开发 (Week 5-7)

**目标**: 完成链下服务与 API 接口

**任务清单**:

- [ ] **区块链监听服务**
  - 合约事件监听 (`TicketMinted`, `TicketTransferred`, `EventCreated`)
  - 数据库同步逻辑
  - 事件处理与状态更新
- [ ] **API 服务开发**
  - RESTful API 设计
  - 购票信息查询接口
  - 验票核销接口
- [ ] **数据管理系统**
  - 数据库设计与优化
  - 数据同步任务调度
  - 缓存策略实施

**交付物**: 后端 API 服务 + 数据同步系统

---

### ✅ 阶段五：集成测试与部署 (Week 7-8)

**目标**: 系统集成、测试与上线准备

**任务清单**:

- [ ] **安全审计**
  - 智能合约安全审计
  - 前端安全检查
  - API 接口安全测试
- [ ] **端到端测试**
  - 完整购票流程测试
  - 二级市场交易测试
  - 线下核销功能测试
- [ ] **部署与上线**
  - 测试网公测
  - 主网合约部署
  - 生产环境配置

**交付物**: 生产就绪的完整系统

## 🛠️ 技术栈

### 智能合约

- **开发框架**: Foundry
- **合约语言**: Solidity ^0.8.19
- **标准协议**: ERC721, ERC20
- **测试工具**: Forge, Anvil
- **DeFi 集成**: Uniswap V3, Chainlink Oracle

### 前端技术

**推荐技术栈**：

- **框架**: React.js / Next.js
- **样式**: Tailwind CSS
- **状态管理**: Redux Toolkit / Zustand
- **区块链交互**: viem
- **钱包连接**: WalletConnect, MetaMask

### 后端技术

- **运行时**: Node.js
- **框架**: Express.js / Fastify
- **数据库**: PostgreSQL / MongoDB
- **区块链交互**: ethers.js
- **任务队列**: Bull / Bee-Queue

### 基础设施

- **部署**: Docker + Kubernetes
- **监控**: Grafana + Prometheus
- **日志**: ELK Stack
- **CI/CD**: GitHub Actions

## 🤖 AI 辅助开发建议

| 开发阶段     | AI 辅助任务                      | 推荐工具                    |
| ------------ | -------------------------------- | --------------------------- |
| **智能合约** | 合约代码生成、测试用例、安全检查 | GitHub Copilot + Foundry    |
| **API 设计** | 接口设计、文档生成、Mock 数据    | Copilot + Swagger/OpenAPI   |
| **前端开发** | 组件生成、样式优化、状态管理     | Copilot + React DevTools    |
| **安全审计** | 漏洞扫描、代码审查、最佳实践     | Slither + Mythril + AI 分析 |
| **测试生成** | 单元测试、集成测试、Fuzz 测试    | Copilot + Foundry Fuzz      |
| **文档编写** | API 文档、用户手册、技术文档     | Copilot + GitBook           |

## � 快速开始

### 环境要求

- Node.js >= 18.0.0
- Foundry (最新版本)
- Git

### 本地开发设置

1. **克隆项目**

```bash
git clone <repository-url>
cd onlineTicket
```

2. **安装依赖**

```bash
# 安装 Foundry 依赖
forge install

# 安装前端依赖 (如果已有前端代码)
npm install
```

3. **编译合约**

```bash
forge build
```

4. **运行测试**

```bash
forge test
```

5. **启动本地节点**

```bash
anvil
```

6. **部署合约到本地网络**

```bash
forge script script/Deploy.s.sol --rpc-url http://localhost:8545 --broadcast
```

## 📁 项目结构

```
onlineTicket/
├── src/
│   ├── TicketManager.sol      # 门票NFT合约
│   ├── EventManager.sol       # 活动管理合约
│   ├── Marketplace.sol        # 交易市场合约
│   ├── PlatformToken.sol      # 平台代币合约
│   └── TokenSwap.sol          # 代币互换合约
├── test/
│   ├── TicketManager.t.sol    # 门票合约测试
│   ├── EventManager.t.sol     # 活动管理测试
│   ├── Marketplace.t.sol      # 市场合约测试
│   └── TokenSwap.t.sol        # 互换合约测试
├── script/
│   ├── Deploy.s.sol           # 部署脚本
│   └── Setup.s.sol            # 初始化脚本
├── lib/                       # Foundry依赖库
├── frontend/                  # 前端应用 (待开发)
├── backend/                   # 后端服务 (待开发)
└── docs/                      # 项目文档
```

## 🔒 安全考虑

### 智能合约安全

- **重入攻击防护**: 使用 ReentrancyGuard
- **整数溢出保护**: Solidity ^0.8.x 内置检查
- **访问控制**: 基于角色的权限管理
- **暂停机制**: 紧急情况下暂停合约功能

### 数据安全

- **私钥管理**: 推荐硬件钱包或 MPC 方案
- **敏感数据加密**: 链下数据加密存储
- **API 安全**: JWT 认证 + HTTPS 传输

## 🌍 未来扩展方向

### Version 2.0 规划

- [ ] **Soulbound Tokens (SBT)**: 不可转让的纪念门票
- [ ] **ERC-6551 集成**: 门票作为智能钱包，支持更多功能
- [ ] **门票碎片化**: 支持门票拆分与组合
- [ ] **投票治理**: 门票持有者参与活动决策
- [ ] **高级 DEX 功能**: 限价订单、止损订单
- [ ] **跨链桥接**: 支持多链代币互换
- [ ] **收益聚合器**: 自动化 DeFi 收益优化

### Version 3.0 愿景

- [ ] **跨链支持**: 多链门票系统
- [ ] **RWA 整合**: 现实资产门票化
- [ ] **DAO 治理**: 去中心化平台治理
- [ ] **DID 集成**: 与 Lens、ENS 等身份系统集成
- [ ] **AI 推荐**: 智能活动推荐系统
- [ ] **社交功能**: 门票社交与分享功能

## 🤝 贡献指南

我们欢迎社区贡献！请遵循以下步骤：

1. Fork 本项目
2. 创建功能分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 开启 Pull Request

### 代码规范

- 智能合约遵循 [Solidity Style Guide](https://docs.soliditylang.org/en/latest/style-guide.html)
- 前端代码使用 ESLint + Prettier
- 提交信息遵循 [Conventional Commits](https://www.conventionalcommits.org/)

## 📄 许可证

本项目采用 MIT 许可证 - 查看 [LICENSE](LICENSE) 文件了解详情。

---

**⚠️ 免责声明**: 本项目仅用于学习和研究目的。在生产环境使用前，请确保进行充分的安全审计和测试。

---

_建设更安全、透明的 Web3 门票生态系统_ 🌟

## 📌 优先级改进建议概览

> 本节为当前代码基础上的分层改进路线（结合安全性、可用性、可扩展性与经济模型）。建议按层推进，上一层达到“完成+测试绿”再进入下一层。时间预估基于单人 / 部分并行（可调整）。

### Tier 0 · 核心稳定 (高优先 / 立即)

聚焦安全与正确性，防止技术债继续累积。

1. Marketplace 拍卖功能：出价、加价、撤回、成交、超时结算与事件；附完整单元+Fuzz 测试。
2. TokenSwap multiSwap：实现最小可用路径 (token↔ETH 多步) 或删除占位 revert 以减小攻击面。
3. 不变量 (Invariant) 测试：

- k = reserveToken \* reserveETH 在无手续费情形不下降（考虑收费后 ≥ 理论最小值）。
- 协议费累积单调不减。
- 闪电贷后 (reserve + fees) ≥ 初始。

4. 访问控制统一：使用 OpenZeppelin AccessControl 角色 (MINTER / VERIFIER / PAUSER / FEE_MANAGER)。
5. FlashLoan 强化：增加最大单次借出比例 (≤ 各储备 50%)，增加事件 FlashLoanExecuted，结束时调用内部储备刷新或延迟标记。
6. 安全工具链：集成 Slither + forge fmt + gas snapshot + (可选) Echidna/Fuzz 工作流到 CI。

### Tier 1 · 功能闭环 (高优先 / 短期 1-2 周)

1. EventManager 深化：活动状态机（Draft/Presale/Sale/Closed）、售罄事件、批量发行 (Merkle / 批量 mint)。
2. TicketManager 扩展：批量核销、可选 SBT（不可转让票种）、EIP-712 签名授权转移 (meta‑tx)。
3. Marketplace 费用模型：区分协议费 vs 创作者分成；添加费率更新延迟 (timelock)。
4. TokenSwap 价格喂价：改进简化 TWAP，采用累积价格取样窗口，暴露 getTWAP(timeWindow) + 上链时间戳校验。
5. 文档：SECURITY.md（威胁模型 + 已实施控制）、CONTRIBUTING 更新测试 & 安全章节。

### Tier 2 · 性能与开发体验 (中优先)

1. Gas 优化：

- 自定义错误替换 require 字符串。
- 缓存储备局部变量减少 SLOAD。
- Marketplace 活跃 listing 结构：使用 EnumerableSet 或紧凑数组 + tombstone 回收策略。

2. 事件索引方案：设计 Subgraph schema（Event / Ticket / Listing / Swap / FlashLoan / FeeWithdrawal）。
3. 前端类型生成：TypeChain / forge bindings 自动化 + CI 产物发布。
4. 统一错误码：合约层 -> 前端映射 (ErrorSelector => 人类可读提示)。
5. 多调用聚合：部署 Multicall/Router（读操作批量请求）。

### Tier 3 · 架构与治理 (中后期)

1. 升级策略：加入 UUPS / Transparent Proxy，冻结 storage layout 文档。
2. 多签 + Timelock：owner 迁移至 Gnosis Safe + TimeLockController (参数/费率/暂停)。
3. 指标与监控：关键事件 (Pause, LargeSwap, FlashLoan, FeeWithdraw) 推送 + Prometheus Exporter（链下服务）。
4. 数据同步服务：事件消费确认机制 & 重放保护；延迟队列重试策略。
5. 费用结算分析：生成 24h volume / fees / APR 统计链下服务，对接前端仪表盘。

### Tier 4 · 高阶与实验 (可选/长期)

1. 票据碎片化 (ERC1155 / ERC3525) 与合成回收。
2. 治理：平台代币投票 / 票权加权治理 (Quadratic / Delegation)。
3. 跨链扩展：LayerZero / CCIP 跨链票据与流动性同步。
4. 激励：LP 挖矿 LiquidityMining 合约 + 奖励线性释放或 veToken 锁仓模型。
5. 链下签名核销快速通道：批量 off-chain accumulate + on-chain finalize。

### 建议执行顺序 (速览)

Tier 0 → (拍卖 + invariants + 权限重构) 完成后合并主分支打 tag v0.2.0，随后进入 Tier 1 封闭功能，完成后安全审计准备。

### 里程碑映射（与原路线图对齐）

| 原路线图阶段       | 对应优先级层 | 衔接说明                                            |
| ------------------ | ------------ | --------------------------------------------------- |
| 阶段一 (合约)      | Tier 0/1     | 在现有基础收尾核心 + 拍卖 + invariants + 事件化完善 |
| 阶段二 (代币/钱包) | Tier 1/2     | 增加签名授权与多调用聚合，提升 UX                   |
| 阶段三 (前端)      | Tier 2       | 依赖前端类型生成 & 错误码体系                       |
| 阶段四 (后端)      | Tier 2/3     | Subgraph + 同步服务 + 指标聚合                      |
| 阶段五 (集成部署)  | Tier 3       | 治理/多签/Timelock 及监控与审计前基线               |

### 近期可执行“首批 PR”建议

- feat(marketplace): implement auction lifecycle + tests + events
- test(invariants): add k, fee, flashLoan repayment invariants (forge-std invariant harness)
- refactor(access): migrate to AccessControl roles, remove bespoke mappings
- chore(ci): add slither + gas snapshot + forge fmt check
- feat(tokenswap): add flashLoan cap + event + reserves sync

需要根据这些条目生成任务 Issue 模板或初始 PR 描述，我可以继续帮助整理。若你指定要先落地哪一条，可直接告诉我优先项，我会生成对应实现骨架与测试。

# 快速开始（在有 anvil 运行的情况下）

PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 make deploy-quick

# 验证部署结果

make verify

# 查看所有可用命令

make help

```shell
# 完整开发流程
make dev-setup     # 设置环境
make anvil-start   # 启动 Anvil（新终端）
make anvil-deploy  # 部署合约
make verify        # 验证部署
make demo         # 运行演示

# 使用 cast 生成新钱包
cast wallet new
# 生成新助记词
cast wallet new-mnemonic
# 从助记词派生密钥
cast wallet derive-private-key "your mnemonic phrase here" 0
```
