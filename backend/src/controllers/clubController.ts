import type { Request, Response } from 'express';
import { AppError } from '../middleware/errorHandler';
import { createClub, getClubById } from '../services/clubService';

export async function createClubController(req: Request, res: Response) {
  if (!req.auth?.userId) {
    throw new AppError(401, 'UNAUTHORIZED', 'Unauthorized');
  }

  const name = typeof req.body?.name === 'string' ? req.body.name : '';
  const region = typeof req.body?.region === 'string' ? req.body.region : '';

  const club = await createClub(req.auth.userId, name, region);
  res.status(201).json(club);
}

export async function getClubController(req: Request, res: Response) {
  const clubId = req.params.id;
  const club = await getClubById(clubId);
  res.status(200).json(club);
}
