import type { Request, Response } from 'express';
import { AppError } from '../../middleware/errorHandler';
import * as matchesService from './matches.service';

export async function listMatches(req: Request, res: Response) {
  if (!req.auth?.userId) {
    throw new AppError(401, 'UNAUTHORIZED', 'Unauthorized');
  }
  const matches = await matchesService.listMatches(req.auth.userId);
  res.status(200).json(matches);
}
