import { Router, Request, Response } from 'express';
import { DatabaseService } from '../services/database';
import { RedisService } from '../services/redis';
import { ApiErrors } from '../middleware/errorHandler';

const router = Router();

// 系统状态
router.get('/status', async (req: Request, res: Response) => {
  try {
    const dbHealth = await DatabaseService.healthCheck();
    const redisHealth = await RedisService.healthCheck();

    const status = {
      database: dbHealth ? 'healthy' : 'unhealthy',
      redis: redisHealth ? 'healthy' : 'unhealthy',
      timestamp: new Date().toISOString()
    };

    res.json({
      success: true,
      data: status
    });

  } catch (error) {
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

// 系统统计
router.get('/stats', async (req: Request, res: Response) => {
  try {
    const db = DatabaseService.getInstance();

    const [userCount, eventCount, ticketCount, orderCount] = await Promise.all([
      db.user.count(),
      db.event.count(),
      db.ticket.count(),
      db.order.count()
    ]);

    const stats = {
      users: userCount,
      events: eventCount,
      tickets: ticketCount,
      orders: orderCount,
      timestamp: new Date().toISOString()
    };

    res.json({
      success: true,
      data: stats
    });

  } catch (error) {
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

export { router as adminRoutes };
