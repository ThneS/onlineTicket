import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import { ApiErrors } from './errorHandler';
import { DatabaseService } from '../services/database';

export interface AuthenticatedRequest extends Request {
  user?: {
    id: string;
    address: string;
  };
}

export const authenticateToken = async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
) => {
  try {
    const authHeader = req.headers.authorization;
    const token = authHeader && authHeader.split(' ')[1]; // Bearer TOKEN

    if (!token) {
      throw ApiErrors.unauthorized('Access token required');
    }

    const jwtSecret = process.env.JWT_SECRET;
    if (!jwtSecret) {
      throw ApiErrors.internalServer('JWT secret not configured');
    }

    const decoded = jwt.verify(token, jwtSecret) as { address: string };

    // 验证用户是否存在
    const db = DatabaseService.getInstance();
    const user = await db.user.findUnique({
      where: { address: decoded.address }
    });

    if (!user) {
      throw ApiErrors.unauthorized('User not found');
    }

    req.user = {
      id: user.id,
      address: user.address
    };

    next();
  } catch (error) {
    if (error instanceof jwt.JsonWebTokenError) {
      next(ApiErrors.unauthorized('Invalid token'));
    } else {
      next(error);
    }
  }
};

export const optionalAuth = async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
) => {
  try {
    const authHeader = req.headers.authorization;
    const token = authHeader && authHeader.split(' ')[1];

    if (token) {
      const jwtSecret = process.env.JWT_SECRET;
      if (jwtSecret) {
        const decoded = jwt.verify(token, jwtSecret) as { address: string };

        const db = DatabaseService.getInstance();
        const user = await db.user.findUnique({
          where: { address: decoded.address }
        });

        if (user) {
          req.user = {
            id: user.id,
            address: user.address
          };
        }
      }
    }

    next();
  } catch (error) {
    // 可选认证，失败时继续执行
    next();
  }
};
