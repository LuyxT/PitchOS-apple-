import type { Request, Response } from 'express';
import { AppError } from '../../middleware/errorHandler';
import * as clubsService from './clubs.service';

export async function createClubController(req: Request, res: Response) {
  if (!req.auth?.userId) {
    throw new AppError(401, 'UNAUTHORIZED', 'Unauthorized');
  }
  const club = await clubsService.createClub(req.auth.userId, req.body);
  res.status(201).json(club);
}

export async function getClubController(req: Request, res: Response) {
  const club = await clubsService.getClubById(req.params.id);
  res.status(200).json(club);
}

export async function listClubsController(_req: Request, res: Response) {
  const clubs = await clubsService.listClubs();
  res.status(200).json(clubs);
}
