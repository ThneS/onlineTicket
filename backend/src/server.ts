import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import morgan from 'morgan';
import rateLimit from 'express-rate-limit';
import dotenv from 'dotenv';

// 导入路由
import { authRoutes } from './routes/auth';
import { eventRoutes } from './routes/events';
import { ticketRoutes } from './routes/tickets';
import { orderRoutes } from './routes/orders';
import { swapRoutes } from './routes/swap';
import { adminRoutes } from './routes/admin';

// 导入中间件
import { errorHandler } from './middleware/errorHandler';
import { logger } from './utils/logger';

// 导入服务
import { DatabaseService } from './services/database';
import { RedisService } from './services/redis';
import { BlockchainSyncService } from './services/blockchainSync';

// 加载环境变量
dotenv.config();

const app = express();
const PORT = process.env.PORT || 3001;

// 安全中间件
app.use(helmet());

// CORS 配置
app.use(cors({
  origin: process.env.CORS_ORIGIN || 'http://localhost:5173',
  credentials: true
}));

// 请求日志
app.use(morgan('combined', {
  stream: { write: (message) => logger.info(message.trim()) }
}));

// 限流
const limiter = rateLimit({
  windowMs: parseInt(process.env.RATE_LIMIT_WINDOW_MS || '900000'), // 15分钟
  max: parseInt(process.env.RATE_LIMIT_MAX_REQUESTS || '100'),
  message: { error: '请求太频繁，请稍后再试' }
});
app.use(limiter);

// 解析请求体
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

// 健康检查
app.get('/health', (req, res) => {
  res.json({
    status: 'OK',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    environment: process.env.NODE_ENV
  });
});

// API 路由
const apiPrefix = process.env.API_PREFIX || '/api/v1';
app.use(`${apiPrefix}/auth`, authRoutes);
app.use(`${apiPrefix}/events`, eventRoutes);
app.use(`${apiPrefix}/tickets`, ticketRoutes);
app.use(`${apiPrefix}/orders`, orderRoutes);
app.use(`${apiPrefix}/swap`, swapRoutes);
app.use(`${apiPrefix}/admin`, adminRoutes);

// 404 处理
app.use('*', (req, res) => {
  res.status(404).json({
    error: 'API 端点不存在',
    path: req.originalUrl
  });
});

// 错误处理中间件
app.use(errorHandler);

// 启动服务器
async function startServer() {
  try {
    // 初始化数据库连接
    await DatabaseService.initialize();
    logger.info('数据库连接成功');

    // 初始化 Redis 连接
    await RedisService.initialize();
    logger.info('Redis 连接成功');

    // 启动区块链同步服务
    const blockchainSync = new BlockchainSyncService();
    await blockchainSync.start();
    logger.info('区块链同步服务启动');

    // 启动 HTTP 服务器
    app.listen(PORT, () => {
      logger.info(`🚀 服务器启动成功，端口: ${PORT}`);
      logger.info(`📖 API 文档: http://localhost:${PORT}${apiPrefix}/docs`);
      logger.info(`🏥 健康检查: http://localhost:${PORT}/health`);
    });

  } catch (error) {
    logger.error('服务器启动失败:', error);
    process.exit(1);
  }
}

// 优雅关闭
process.on('SIGTERM', async () => {
  logger.info('收到 SIGTERM 信号，开始优雅关闭...');
  await DatabaseService.disconnect();
  await RedisService.disconnect();
  process.exit(0);
});

process.on('SIGINT', async () => {
  logger.info('收到 SIGINT 信号，开始优雅关闭...');
  await DatabaseService.disconnect();
  await RedisService.disconnect();
  process.exit(0);
});

// 启动应用
startServer().catch(error => {
  logger.error('应用启动失败:', error);
  process.exit(1);
});
