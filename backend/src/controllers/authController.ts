import type { Request, Response } from 'express';
import { UserRole } from '@prisma/client';
import { AppError } from '../middleware/errorHandler';
import { getAuthenticatedUser, loginUser, registerUser } from '../services/authService';

function parseRole(value: unknown): UserRole {
  if (value === 'trainer' || value === 'player' || value === 'board') {
    return value;
  }
  return 'trainer';
}

export async function registerController(req: Request, res: Response) {
  const email = typeof req.body?.email === 'string' ? req.body.email : '';
  const password = typeof req.body?.password === 'string' ? req.body.password : '';
  const role = parseRole(req.body?.role);

  if (!email || !password) {
    throw new AppError(400, 'INVALID_INPUT', 'email and password are required');
  }

  const result = await registerUser({ email, password, role }, req.app.locals.jwtSecret as string);
  res.status(201).json(result);
}

export async function loginController(req: Request, res: Response) {
  const email = typeof req.body?.email === 'string' ? req.body.email : '';
  const password = typeof req.body?.password === 'string' ? req.body.password : '';

  if (!email || !password) {
    throw new AppError(400, 'INVALID_INPUT', 'email and password are required');
  }

  const result = await loginUser({ email, password }, req.app.locals.jwtSecret as string);
  res.status(200).json(result);
}

export async function meController(req: Request, res: Response) {
  if (!req.auth?.userId) {
    throw new AppError(401, 'UNAUTHORIZED', 'Unauthorized');
  }

  const user = await getAuthenticatedUser(req.auth.userId);
  res.status(200).json(user);
}
