import type { Request, Response } from 'express';
import { AppError } from '../middleware/errorHandler';
import { createTeam, getTeamById } from '../services/teamService';

export async function createTeamController(req: Request, res: Response) {
  if (!req.auth?.userId) {
    throw new AppError(401, 'UNAUTHORIZED', 'Unauthorized');
  }

  const name = typeof req.body?.name === 'string' ? req.body.name : '';
  const clubId = typeof req.body?.clubId === 'string' ? req.body.clubId : undefined;

  const team = await createTeam(req.auth.userId, name, clubId);
  res.status(201).json(team);
}

export async function getTeamController(req: Request, res: Response) {
  const team = await getTeamById(req.params.id);
  res.status(200).json(team);
}
