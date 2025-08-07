import { DatabaseService } from '../services/database';
import { logger } from '../utils/logger';

async function seedDatabase() {
  try {
    logger.info('开始数据库初始化...');

    const db = await DatabaseService.initialize();

    // 创建示例用户
    const users = await Promise.all([
      db.user.upsert({
        where: { address: '0x70997970c51812dc3a010c7d01b50e0d17dc79c8' },
        update: {},
        create: {
          address: '0x70997970c51812dc3a010c7d01b50e0d17dc79c8'
        }
      }),
      db.user.upsert({
        where: { address: '0x3c44cdddb6a900fa2b585dd299e03d12fa4293bc' },
        update: {},
        create: {
          address: '0x3c44cdddb6a900fa2b585dd299e03d12fa4293bc'
        }
      })
    ]);

    logger.info(`创建了 ${users.length} 个用户`);

    // 创建示例活动
    const events = await Promise.all([
      db.event.upsert({
        where: {
          chainId_contractId: {
            chainId: 31337,
            contractId: '1'
          }
        },
        update: {},
        create: {
          chainId: 31337,
          contractId: '1',
          name: '音乐节 2025',
          description: '一年一度的盛大音乐节，汇聚全球顶级艺人',
          location: '上海体育场',
          startTime: new Date('2025-08-15T19:00:00Z'),
          endTime: new Date('2025-08-15T23:00:00Z'),
          maxTickets: 1000,
          ticketPrice: '299000000000000000000', // 299 ETH in wei
          organizerId: users[0].id
        }
      }),
      db.event.upsert({
        where: {
          chainId_contractId: {
            chainId: 31337,
            contractId: '2'
          }
        },
        update: {},
        create: {
          chainId: 31337,
          contractId: '2',
          name: '科技大会',
          description: '探索未来科技趋势，与行业领袖面对面交流',
          location: '深圳会展中心',
          startTime: new Date('2025-09-20T09:00:00Z'),
          endTime: new Date('2025-09-20T18:00:00Z'),
          maxTickets: 500,
          ticketPrice: '599000000000000000000', // 599 ETH in wei
          organizerId: users[1].id
        }
      })
    ]);

    logger.info(`创建了 ${events.length} 个活动`);

    // 创建示例代币价格
    const tokenPrices = await Promise.all([
      db.tokenPrice.upsert({
        where: {
          tokenA_tokenB: {
            tokenA: process.env.PLATFORM_TOKEN_ADDRESS || '0x5FbDB2315678afecb367f032d93F642f64180aa3',
            tokenB: '0x0000000000000000000000000000000000000000' // ETH
          }
        },
        update: { price: '0.001', timestamp: new Date() },
        create: {
          tokenA: process.env.PLATFORM_TOKEN_ADDRESS || '0x5FbDB2315678afecb367f032d93F642f64180aa3',
          tokenB: '0x0000000000000000000000000000000000000000',
          price: '0.001',
          source: 'internal'
        }
      })
    ]);

    logger.info(`创建了 ${tokenPrices.length} 个代币价格记录`);

    logger.info('数据库初始化完成！');

  } catch (error) {
    logger.error('数据库初始化失败:', error);
    process.exit(1);
  } finally {
    await DatabaseService.disconnect();
  }
}

// 如果直接运行此脚本
if (require.main === module) {
  seedDatabase();
}

export { seedDatabase };
