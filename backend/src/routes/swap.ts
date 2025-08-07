import { Router, Request, Response } from 'express';
import { DatabaseService } from '../services/database';
import { RedisService } from '../services/redis';
import { ApiErrors } from '../middleware/errorHandler';

const router = Router();

// 获取代币价格
router.get('/prices', async (req: Request, res: Response) => {
  try {
    const db = DatabaseService.getInstance();

    const prices = await db.tokenPrice.findMany({
      orderBy: { timestamp: 'desc' },
      take: 50
    });

    res.json({
      success: true,
      data: prices
    });

  } catch (error) {
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

// 获取流动性池信息
router.get('/pools', async (req: Request, res: Response) => {
  try {
    const db = DatabaseService.getInstance();

    const pools = await db.liquidityPool.findMany({
      orderBy: { updatedAt: 'desc' }
    });

    res.json({
      success: true,
      data: pools
    });

  } catch (error) {
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

// 计算交换价格 (模拟)
router.post('/quote', async (req: Request, res: Response) => {
  try {
    const { tokenIn, tokenOut, amountIn } = req.body;

    if (!tokenIn || !tokenOut || !amountIn) {
      throw ApiErrors.badRequest('缺少必要参数');
    }

    // 简单的价格计算逻辑
    // 实际项目中应该根据AMM公式计算
    const mockPrice = 1.0; // 1:1 兑换率
    const amountOut = parseFloat(amountIn) * mockPrice;

    res.json({
      success: true,
      data: {
        tokenIn,
        tokenOut,
        amountIn,
        amountOut: amountOut.toString(),
        priceImpact: '0.1',
        fee: '0.3'
      }
    });

  } catch (error) {
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

export { router as swapRoutes };
