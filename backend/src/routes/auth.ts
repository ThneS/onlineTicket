import { Router, Request, Response } from 'express';
import jwt from 'jsonwebtoken';
import { DatabaseService } from '../services/database';
import { ApiErrors } from '../middleware/errorHandler';
import { logger } from '../utils/logger';

const router = Router();

// 生成随机 nonce
router.post('/nonce', async (req: Request, res: Response) => {
  try {
    const { address } = req.body;

    if (!address) {
      throw ApiErrors.badRequest('钱包地址是必需的');
    }

    // 生成随机 nonce
    const nonce = Math.random().toString(36).substring(2, 15);

    const db = DatabaseService.getInstance();

    // 更新或创建用户的 nonce
    await db.user.upsert({
      where: { address: address.toLowerCase() },
      update: { nonce },
      create: {
        address: address.toLowerCase(),
        nonce
      }
    });

    res.json({
      success: true,
      data: { nonce }
    });

  } catch (error) {
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

// 验证签名并登录
router.post('/login', async (req: Request, res: Response) => {
  try {
    const { address, signature, message } = req.body;

    if (!address || !signature || !message) {
      throw ApiErrors.badRequest('地址、签名和消息都是必需的');
    }

    const db = DatabaseService.getInstance();

    // 查找用户
    const user = await db.user.findUnique({
      where: { address: address.toLowerCase() }
    });

    if (!user || !user.nonce) {
      throw ApiErrors.unauthorized('无效的用户或 nonce');
    }

    // TODO: 验证签名
    // 这里应该验证用户签名的消息是否包含正确的 nonce
    // 实际项目中需要使用 ethers 或 viem 来验证签名

    // 清除 nonce
    await db.user.update({
      where: { id: user.id },
      data: { nonce: null }
    });

    // 生成 JWT token
    const jwtSecret = process.env.JWT_SECRET;
    if (!jwtSecret) {
      throw ApiErrors.internalServer('JWT secret not configured');
    }

    const token = jwt.sign(
      { address: user.address },
      jwtSecret,
      { expiresIn: process.env.JWT_EXPIRES_IN || '7d' }
    );

    logger.info(`用户登录成功: ${user.address}`);

    res.json({
      success: true,
      data: {
        token,
        user: {
          id: user.id,
          address: user.address,
          createdAt: user.createdAt
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

// 刷新 token
router.post('/refresh', async (req: Request, res: Response) => {
  try {
    const { refreshToken } = req.body;

    if (!refreshToken) {
      throw ApiErrors.badRequest('Refresh token is required');
    }

    // TODO: 实现 refresh token 逻辑
    res.json({
      success: false,
      error: 'Refresh token not implemented yet'
    });

  } catch (error) {
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

export { router as authRoutes };
