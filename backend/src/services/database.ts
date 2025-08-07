import { PrismaClient } from '@prisma/client';
import { logger } from '../utils/logger';

export class DatabaseService {
  private static instance: PrismaClient;

  static async initialize(): Promise<PrismaClient> {
    if (!this.instance) {
      this.instance = new PrismaClient({
        log: [
          { level: 'query', emit: 'event' },
          { level: 'error', emit: 'stdout' },
          { level: 'info', emit: 'stdout' },
          { level: 'warn', emit: 'stdout' },
        ],
      });

      // 监听查询事件用于调试
      this.instance.$on('query', (e) => {
        if (process.env.LOG_LEVEL === 'debug') {
          logger.debug('Database Query', {
            query: e.query,
            params: e.params,
            duration: `${e.duration}ms`
          });
        }
      });

      await this.instance.$connect();
      logger.info('数据库连接已建立');
    }

    return this.instance;
  }

  static getInstance(): PrismaClient {
    if (!this.instance) {
      throw new Error('数据库未初始化，请先调用 initialize()');
    }
    return this.instance;
  }

  static async disconnect(): Promise<void> {
    if (this.instance) {
      await this.instance.$disconnect();
      logger.info('数据库连接已断开');
    }
  }

  // 健康检查
  static async healthCheck(): Promise<boolean> {
    try {
      await this.getInstance().$queryRaw`SELECT 1`;
      return true;
    } catch (error) {
      logger.error('数据库健康检查失败:', error);
      return false;
    }
  }
}
