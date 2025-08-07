# OnlineTicket 后端 API 服务

基于 Node.js + Express + Prisma + Redis 构建的 Web3 票务平台后端服务。

## 🚀 功能特性

- **REST API**: 完整的 RESTful API 接口
- **区块链同步**: 自动同步区块链事件到数据库
- **数据缓存**: Redis 缓存提升性能
- **用户认证**: JWT 身份验证
- **数据库**: PostgreSQL + Prisma ORM
- **日志系统**: Winston 结构化日志
- **错误处理**: 统一错误处理中间件
- **类型安全**: 完整的 TypeScript 支持

## 📁 项目结构

```
backend/
├── src/
│   ├── routes/              # API 路由
│   │   ├── auth.ts         # 用户认证
│   │   ├── events.ts       # 活动管理
│   │   ├── tickets.ts      # 门票管理
│   │   ├── orders.ts       # 订单管理
│   │   ├── swap.ts         # 代币交换
│   │   └── admin.ts        # 系统管理
│   ├── services/           # 业务服务
│   │   ├── database.ts     # 数据库服务
│   │   ├── redis.ts        # 缓存服务
│   │   └── blockchainSync.ts # 区块链同步
│   ├── middleware/         # 中间件
│   │   ├── auth.ts         # 认证中间件
│   │   └── errorHandler.ts # 错误处理
│   ├── utils/              # 工具类
│   │   └── logger.ts       # 日志工具
│   ├── scripts/            # 脚本
│   │   └── seed.ts         # 数据初始化
│   └── server.ts           # 服务器入口
├── prisma/
│   └── schema.prisma       # 数据库模式
├── logs/                   # 日志文件
└── package.json
```

## 🛠️ 技术栈

- **运行时**: Node.js 18+
- **框架**: Express.js
- **数据库**: PostgreSQL
- **ORM**: Prisma
- **缓存**: Redis
- **认证**: JWT
- **日志**: Winston
- **区块链**: Viem

## 🚀 快速开始

### 环境要求

- Node.js >= 18.0.0
- PostgreSQL >= 13
- Redis >= 6
- 运行中的以太坊节点 (Anvil/Hardhat)

### 1. 安装依赖

```bash
npm install
```

### 2. 环境配置

```bash
# 复制环境变量文件
cp .env.example .env

# 编辑环境变量
vim .env
```

### 3. 数据库设置

```bash
# 生成 Prisma 客户端
npx prisma generate

# 执行数据库迁移
npx prisma migrate dev --name init

# 初始化数据 (可选)
npm run db:seed
```

### 4. 启动服务

```bash
# 开发模式
npm run dev

# 生产模式
npm run build
npm start

# 使用启动脚本
chmod +x start.sh
./start.sh
```

## 📚 API 文档

### 认证相关

- `POST /api/v1/auth/nonce` - 获取登录随机数
- `POST /api/v1/auth/login` - 用户登录

### 活动管理

- `GET /api/v1/events` - 获取活动列表
- `GET /api/v1/events/:id` - 获取活动详情
- `GET /api/v1/events/:id/stats` - 获取活动统计

### 门票管理

- `GET /api/v1/tickets/my` - 获取我的门票 (需认证)
- `GET /api/v1/tickets/:id` - 获取门票详情

### 订单管理

- `GET /api/v1/orders/my` - 获取我的订单 (需认证)
- `GET /api/v1/orders/:id` - 获取订单详情 (需认证)

### 代币交换

- `GET /api/v1/swap/prices` - 获取代币价格
- `GET /api/v1/swap/pools` - 获取流动性池
- `POST /api/v1/swap/quote` - 计算交换价格

### 系统管理

- `GET /api/v1/admin/status` - 系统状态
- `GET /api/v1/admin/stats` - 系统统计

## 🔧 开发命令

| 命令                 | 描述           |
| -------------------- | -------------- |
| `npm run dev`        | 启动开发服务器 |
| `npm run build`      | 构建生产版本   |
| `npm start`          | 启动生产服务器 |
| `npm test`           | 运行测试       |
| `npm run lint`       | 代码检查       |
| `npm run db:migrate` | 数据库迁移     |
| `npm run db:seed`    | 初始化数据     |

## 🌐 服务端点

- **HTTP API**: http://localhost:3001
- **健康检查**: http://localhost:3001/health
- **API 文档**: http://localhost:3001/api/v1/docs (计划中)

## 📊 监控和日志

### 日志文件

- `logs/combined.log` - 综合日志
- `logs/error.log` - 错误日志
- 控制台输出 - 开发环境实时日志

### 健康检查

```bash
curl http://localhost:3001/health
```

### 系统状态

```bash
curl http://localhost:3001/api/v1/admin/status
```

## 🔄 区块链同步

后端服务会自动监听并同步以下区块链事件：

- **EventCreated** - 新活动创建
- **TicketMinted** - 门票铸造
- **Transfer** - 门票转移
- **OrderCreated** - 订单创建

同步间隔：30 秒

## 💾 数据库模式

### 主要表结构

- **users** - 用户信息
- **events** - 活动信息
- **tickets** - 门票信息
- **orders** - 订单信息
- **token_prices** - 代币价格
- **liquidity_pools** - 流动性池
- **blockchain_sync** - 同步状态

## 🔒 安全特性

- **JWT 认证** - 接口访问控制
- **限流保护** - 防止 API 滥用
- **CORS 配置** - 跨域请求控制
- **Helmet 中间件** - HTTP 安全头
- **输入验证** - 参数校验和清理

## 🚀 部署指南

### Docker 部署 (计划中)

```bash
# 构建镜像
docker build -t onlineticket-backend .

# 运行容器
docker run -p 3001:3001 onlineticket-backend
```

### 环境变量配置

生产环境需要配置以下关键变量：

- `NODE_ENV=production`
- `DATABASE_URL` - 生产数据库连接
- `REDIS_URL` - Redis 连接
- `JWT_SECRET` - JWT 密钥
- `RPC_URL` - 主网/测试网 RPC 端点

## 🤝 开发指南

### 添加新的 API 端点

1. 在 `src/routes/` 中创建路由文件
2. 在 `src/server.ts` 中注册路由
3. 添加相应的测试用例

### 数据库模式变更

1. 修改 `prisma/schema.prisma`
2. 运行 `npx prisma migrate dev --name <migration-name>`
3. 更新种子数据 (如需要)

### 区块链事件处理

1. 在 `src/services/blockchainSync.ts` 中添加事件处理器
2. 定义对应的 ABI 片段
3. 实现数据同步逻辑

## 📈 性能优化

- **数据库索引** - 关键字段建立索引
- **Redis 缓存** - 热点数据缓存
- **连接池** - 数据库连接复用
- **分页查询** - 大数据集分页处理

## 🔍 故障排除

### 常见问题

1. **数据库连接失败**

   - 检查 `DATABASE_URL` 配置
   - 确认 PostgreSQL 服务运行状态

2. **区块链同步异常**

   - 检查 `RPC_URL` 配置
   - 确认合约地址正确

3. **Redis 连接失败**
   - 检查 `REDIS_URL` 配置
   - 确认 Redis 服务运行状态

### 调试模式

```bash
# 启用调试日志
LOG_LEVEL=debug npm run dev
```

## 📄 许可证

MIT License - 查看 [LICENSE](../LICENSE) 文件了解详情。
