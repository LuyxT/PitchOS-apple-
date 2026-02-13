import type { Request, Response } from 'express';
import { AppError } from '../../middleware/errorHandler';
import * as authService from './auth.service';
import type { AppEnv } from '../../config/env';

function getTokenConfig(req: Request) {
  const env = req.app.locals.env as AppEnv;
  return {
    accessSecret: env.JWT_ACCESS_SECRET,
    refreshSecret: env.JWT_REFRESH_SECRET,
    accessTtl: env.JWT_ACCESS_TTL,
    refreshTtl: env.JWT_REFRESH_TTL,
  };
}

export async function registerController(req: Request, res: Response) {
  const config = getTokenConfig(req);
  const result = await authService.register(req.body, config);
  res.status(201).json(result);
}

export async function loginController(req: Request, res: Response) {
  const config = getTokenConfig(req);
  const result = await authService.login(req.body, config);
  res.status(200).json(result);
}

export async function refreshController(req: Request, res: Response) {
  const config = getTokenConfig(req);
  const result = await authService.refresh(req.body.refreshToken, config);
  res.status(200).json(result);
}

export async function meController(req: Request, res: Response) {
  if (!req.auth?.userId) {
    throw new AppError(401, 'UNAUTHORIZED', 'Unauthorized');
  }
  const result = await authService.getMe(req.auth.userId);
  res.status(200).json(result);
}

export async function logoutController(req: Request, res: Response) {
  if (!req.auth?.userId) {
    throw new AppError(401, 'UNAUTHORIZED', 'Unauthorized');
  }
  const refreshToken = typeof req.body?.refreshToken === 'string' ? req.body.refreshToken : undefined;
  await authService.logout(req.auth.userId, refreshToken);
  res.status(200).json({ success: true });
}

export async function deleteAccountController(req: Request, res: Response) {
  if (!req.auth?.userId) {
    throw new AppError(401, 'UNAUTHORIZED', 'Unauthorized');
  }
  await authService.deleteAccount(req.auth.userId);
  res.status(200).json({ success: true });
}
