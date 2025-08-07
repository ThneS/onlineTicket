import { Router, Request, Response } from 'express';
import { DatabaseService } from '../services/database';
import { ApiErrors } from '../middleware/errorHandler';
import { authenticateToken, AuthenticatedRequest } from '../middleware/auth';

const router = Router();

// 获取用户门票
router.get('/my', authenticateToken, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const userId = req.user?.id;

    const db = DatabaseService.getInstance();
    const tickets = await db.ticket.findMany({
      where: { ownerId: userId },
      include: {
        event: {
          select: {
            id: true,
            name: true,
            startTime: true,
            endTime: true,
            location: true
          }
        }
      },
      orderBy: { createdAt: 'desc' }
    });

    res.json({
      success: true,
      data: tickets
    });

  } catch (error) {
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

// 获取门票详情
router.get('/:id', async (req: Request, res: Response) => {
  try {
    const { id } = req.params;

    const db = DatabaseService.getInstance();
    const ticket = await db.ticket.findUnique({
      where: { id },
      include: {
        event: true,
        owner: {
          select: {
            address: true
          }
        }
      }
    });

    if (!ticket) {
      throw ApiErrors.notFound('门票不存在');
    }

    res.json({
      success: true,
      data: ticket
    });

  } catch (error) {
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

export { router as ticketRoutes };
