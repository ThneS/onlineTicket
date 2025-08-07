import { Router, Request, Response } from 'express';
import { DatabaseService } from '../services/database';
import { ApiErrors } from '../middleware/errorHandler';
import { authenticateToken, AuthenticatedRequest } from '../middleware/auth';

const router = Router();

// 获取用户订单
router.get('/my', authenticateToken, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const userId = req.user?.id;
    const { page = 1, limit = 10 } = req.query;

    const pageNum = parseInt(page as string);
    const limitNum = parseInt(limit as string);
    const skip = (pageNum - 1) * limitNum;

    const db = DatabaseService.getInstance();

    const [orders, total] = await Promise.all([
      db.order.findMany({
        where: { buyerId: userId },
        skip,
        take: limitNum,
        orderBy: { createdAt: 'desc' },
        include: {
          event: {
            select: {
              id: true,
              name: true,
              startTime: true,
              endTime: true
            }
          },
          ticket: {
            select: {
              id: true,
              tokenId: true,
              seatNumber: true
            }
          }
        }
      }),
      db.order.count({ where: { buyerId: userId } })
    ]);

    res.json({
      success: true,
      data: {
        orders,
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

// 获取订单详情
router.get('/:id', authenticateToken, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const { id } = req.params;
    const userId = req.user?.id;

    const db = DatabaseService.getInstance();
    const order = await db.order.findFirst({
      where: {
        id,
        buyerId: userId
      },
      include: {
        event: true,
        ticket: true,
        buyer: {
          select: {
            address: true
          }
        }
      }
    });

    if (!order) {
      throw ApiErrors.notFound('订单不存在或无权访问');
    }

    res.json({
      success: true,
      data: order
    });

  } catch (error) {
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

export { router as orderRoutes };
