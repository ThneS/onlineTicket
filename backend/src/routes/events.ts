import { Router, Request, Response } from 'express';
import { DatabaseService } from '../services/database';
import { RedisService } from '../services/redis';
import { ApiErrors } from '../middleware/errorHandler';
import { optionalAuth, AuthenticatedRequest } from '../middleware/auth';

const router = Router();

// 获取活动列表
router.get('/', optionalAuth, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const { page = 1, limit = 10, search, isActive } = req.query;

    const pageNum = parseInt(page as string);
    const limitNum = parseInt(limit as string);
    const skip = (pageNum - 1) * limitNum;

    // 构建查询条件
    const where: any = {};

    if (search) {
      where.OR = [
        { name: { contains: search as string, mode: 'insensitive' } },
        { description: { contains: search as string, mode: 'insensitive' } }
      ];
    }

    if (isActive !== undefined) {
      where.isActive = isActive === 'true';
    }

    const db = DatabaseService.getInstance();

    // 查询活动
    const [events, total] = await Promise.all([
      db.event.findMany({
        where,
        skip,
        take: limitNum,
        orderBy: { createdAt: 'desc' },
        include: {
          organizer: {
            select: {
              id: true,
              address: true
            }
          },
          _count: {
            select: {
              tickets: true,
              orders: true
            }
          }
        }
      }),
      db.event.count({ where })
    ]);

    res.json({
      success: true,
      data: {
        events,
        pagination: {
          page: pageNum,
          limit: limitNum,
          total,
          pages: Math.ceil(total / limitNum)
        }
      }
    });

  } catch (error) {
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

// 获取活动详情
router.get('/:id', optionalAuth, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const { id } = req.params;

    // 先从缓存中查找
    const cacheKey = RedisService.generateKey('event', id);
    let event = await RedisService.getJSON(cacheKey);

    if (!event) {
      const db = DatabaseService.getInstance();
      event = await db.event.findUnique({
        where: { id },
        include: {
          organizer: {
            select: {
              id: true,
              address: true
            }
          },
          tickets: {
            select: {
              id: true,
              tokenId: true,
              seatNumber: true,
              isUsed: true,
              owner: {
                select: {
                  address: true
                }
              }
            }
          },
          _count: {
            select: {
              tickets: true,
              orders: true
            }
          }
        }
      });

      if (!event) {
        throw ApiErrors.notFound('活动不存在');
      }

      // 缓存 5 分钟
      await RedisService.setJSON(cacheKey, event, 300);
    }

    res.json({
      success: true,
      data: event
    });

  } catch (error) {
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

// 获取活动统计信息
router.get('/:id/stats', async (req: Request, res: Response) => {
  try {
    const { id } = req.params;

    const db = DatabaseService.getInstance();

    // 检查活动是否存在
    const event = await db.event.findUnique({
      where: { id },
      select: { id: true, maxTickets: true }
    });

    if (!event) {
      throw ApiErrors.notFound('活动不存在');
    }

    // 获取统计数据
    const [ticketCount, soldCount, usedCount] = await Promise.all([
      db.ticket.count({
        where: { eventId: id }
      }),
      db.order.count({
        where: {
          eventId: id,
          status: 'CONFIRMED'
        }
      }),
      db.ticket.count({
        where: {
          eventId: id,
          isUsed: true
        }
      })
    ]);

    const stats = {
      totalTickets: event.maxTickets,
      mintedTickets: ticketCount,
      soldTickets: soldCount,
      usedTickets: usedCount,
      availableTickets: event.maxTickets - ticketCount,
      salesRate: event.maxTickets > 0 ? (soldCount / event.maxTickets * 100) : 0,
      usageRate: ticketCount > 0 ? (usedCount / ticketCount * 100) : 0
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

export { router as eventRoutes };
