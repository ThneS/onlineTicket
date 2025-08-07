import { createClient, RedisClientType } from 'redis';
import { logger } from '../utils/logger';

export class RedisService {
  private static instance: RedisClientType;

  static async initialize(): Promise<RedisClientType> {
    if (!this.instance) {
      this.instance = createClient({
        url: process.env.REDIS_URL || 'redis://localhost:6379'
      });

      this.instance.on('error', (err) => {
        logger.error('Redis 连接错误:', err);
      });

      this.instance.on('connect', () => {
        logger.info('Redis 连接已建立');
      });

      await this.instance.connect();
    }

    return this.instance;
  }

  static getInstance(): RedisClientType {
    if (!this.instance) {
      throw new Error('Redis 未初始化，请先调用 initialize()');
    }
    return this.instance;
  }

  static async disconnect(): Promise<void> {
    if (this.instance) {
      await this.instance.disconnect();
      logger.info('Redis 连接已断开');
    }
  }

  // 缓存方法
  static async set(key: string, value: string, expireInSeconds?: number): Promise<void> {
    const redis = this.getInstance();
    if (expireInSeconds) {
      await redis.setEx(key, expireInSeconds, value);
    } else {
      await redis.set(key, value);
    }
  }

  static async get(key: string): Promise<string | null> {
    const redis = this.getInstance();
    return await redis.get(key);
  }

  static async del(key: string): Promise<number> {
    const redis = this.getInstance();
    return await redis.del(key);
  }

  static async exists(key: string): Promise<number> {
    const redis = this.getInstance();
    return await redis.exists(key);
  }

  // JSON 缓存方法
  static async setJSON(key: string, value: any, expireInSeconds?: number): Promise<void> {
    await this.set(key, JSON.stringify(value), expireInSeconds);
  }

  static async getJSON<T>(key: string): Promise<T | null> {
    const value = await this.get(key);
    return value ? JSON.parse(value) : null;
  }

  // 健康检查
  static async healthCheck(): Promise<boolean> {
    try {
      const redis = this.getInstance();
      await redis.ping();
      return true;
    } catch (error) {
      logger.error('Redis 健康检查失败:', error);
      return false;
    }
  }

  // 缓存键生成器
  static generateKey(namespace: string, id: string): string {
    return `onlineticket:${namespace}:${id}`;
  }
}
