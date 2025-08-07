import { Request, Response, NextFunction } from 'express';
import { logger } from '../utils/logger';

export interface ApiError extends Error {
  statusCode?: number;
  isOperational?: boolean;
}

export const errorHandler = (
  err: ApiError,
  req: Request,
  res: Response,
  next: NextFunction
) => {
  const statusCode = err.statusCode || 500;
  const message = err.message || 'Internal Server Error';

  // 记录错误日志
  logger.error('API Error', {
    error: err.message,
    stack: err.stack,
    url: req.url,
    method: req.method,
    ip: req.ip,
    userAgent: req.get('User-Agent')
  });

  // 发送错误响应
  res.status(statusCode).json({
    success: false,
    error: {
      message,
      ...(process.env.NODE_ENV === 'development' && { stack: err.stack })
    },
    timestamp: new Date().toISOString(),
    path: req.url
  });
};

// 创建 API 错误的工厂函数
export const createApiError = (message: string, statusCode: number = 500): ApiError => {
  const error = new Error(message) as ApiError;
  error.statusCode = statusCode;
  error.isOperational = true;
  return error;
};

// 常用错误类型
export const ApiErrors = {
  badRequest: (message = 'Bad Request') => createApiError(message, 400),
  unauthorized: (message = 'Unauthorized') => createApiError(message, 401),
  forbidden: (message = 'Forbidden') => createApiError(message, 403),
  notFound: (message = 'Not Found') => createApiError(message, 404),
  conflict: (message = 'Conflict') => createApiError(message, 409),
  validationError: (message = 'Validation Error') => createApiError(message, 422),
  internalServer: (message = 'Internal Server Error') => createApiError(message, 500)
};
