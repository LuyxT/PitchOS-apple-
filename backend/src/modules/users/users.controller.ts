import type { Request, Response } from 'express';
import { AppError } from '../../middleware/errorHandler';
import * as usersService from './users.service';

export async function getMeController(req: Request, res: Response) {
  if (!req.auth?.userId) {
    throw new AppError(401, 'UNAUTHORIZED', 'Unauthorized');
  }
  const user = await usersService.getUserById(req.auth.userId);
  res.status(200).json(user);
}

export async function updateProfileController(req: Request, res: Response) {
  if (!req.auth?.userId) {
    throw new AppError(401, 'UNAUTHORIZED', 'Unauthorized');
  }
  const user = await usersService.updateUserProfile(req.auth.userId, req.body);
  res.status(200).json(user);
}
