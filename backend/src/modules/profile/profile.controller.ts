import type { Request, Response } from 'express';
import { AppError } from '../../middleware/errorHandler';
import * as profileService from './profile.service';

export async function getProfileController(req: Request, res: Response) {
  if (!req.auth?.userId) {
    throw new AppError(401, 'UNAUTHORIZED', 'Unauthorized');
  }
  const result = await profileService.getProfile(req.auth.userId);
  res.status(200).json(result);
}

export async function saveProfileController(req: Request, res: Response) {
  if (!req.auth?.userId) {
    throw new AppError(401, 'UNAUTHORIZED', 'Unauthorized');
  }
  const result = await profileService.saveProfile(req.auth.userId, req.body);
  res.status(200).json(result);
}
