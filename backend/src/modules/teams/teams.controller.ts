import type { Request, Response } from 'express';
import { AppError } from '../../middleware/errorHandler';
import * as teamsService from './teams.service';

export async function createTeamController(req: Request, res: Response) {
  if (!req.auth?.userId) {
    throw new AppError(401, 'UNAUTHORIZED', 'Unauthorized');
  }
  const team = await teamsService.createTeam(req.auth.userId, req.body);
  res.status(201).json(team);
}

export async function getTeamController(req: Request, res: Response) {
  const team = await teamsService.getTeamById(req.params.id);
  res.status(200).json(team);
}

export async function listTeamsController(req: Request, res: Response) {
  const clubId = typeof req.query.clubId === 'string' ? req.query.clubId : '';
  if (!clubId) {
    throw new AppError(400, 'MISSING_CLUB_ID', 'clubId query parameter is required');
  }
  const teams = await teamsService.listTeamsByClub(clubId);
  res.status(200).json(teams);
}
