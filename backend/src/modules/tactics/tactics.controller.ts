import type { Request, Response } from 'express';
import { AppError } from '../../middleware/errorHandler';
import * as tacticsService from './tactics.service';

export async function listTacticBoards(req: Request, res: Response) {
  if (!req.auth?.userId) {
    throw new AppError(401, 'UNAUTHORIZED', 'Unauthorized');
  }
  // Legacy endpoint - returns empty array
  res.status(200).json([]);
}

export async function getTacticsState(req: Request, res: Response) {
  if (!req.auth?.userId) {
    throw new AppError(401, 'UNAUTHORIZED', 'Unauthorized');
  }
  const state = await tacticsService.getTacticsState(req.auth.userId);
  res.status(200).json(state);
}

export async function saveTacticsState(req: Request, res: Response) {
  if (!req.auth?.userId) {
    throw new AppError(401, 'UNAUTHORIZED', 'Unauthorized');
  }
  const state = await tacticsService.saveTacticsState(req.auth.userId, req.body);
  res.status(200).json(state);
}
