import type { RequestHandler } from 'express';
import { verifyAccessToken } from '../lib/jwt';
import { AppError } from './errorHandler';

export function authenticate(secret: string): RequestHandler {
  return (req, _res, next) => {
    const header = req.headers.authorization;

    if (!header || !header.startsWith('Bearer ')) {
      next(new AppError(401, 'UNAUTHORIZED', 'Missing bearer token'));
      return;
    }

    const token = header.slice(7).trim();
    if (!token) {
      next(new AppError(401, 'UNAUTHORIZED', 'Missing bearer token'));
      return;
    }

    try {
      req.auth = verifyAccessToken(token, secret);
      next();
    } catch {
      next(new AppError(401, 'UNAUTHORIZED', 'Invalid or expired token'));
    }
  };
}
