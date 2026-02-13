import type { Request, Response } from 'express';
import { AppError } from '../../middleware/errorHandler';
import * as playersService from './players.service';

export async function createPlayerController(req: Request, res: Response) {
  if (!req.auth?.userId) {
    throw new AppError(401, 'UNAUTHORIZED', 'Unauthorized');
  }
  const player = await playersService.createPlayer(req.body);
  res.status(201).json(player);
}

export async function listPlayersController(req: Request, res: Response) {
  const teamId = typeof req.query.teamId === 'string' ? req.query.teamId : undefined;
  const players = await playersService.listPlayers(teamId);
  res.status(200).json(players);
}

export async function getPlayerController(req: Request, res: Response) {
  const player = await playersService.getPlayerById(req.params.id);
  res.status(200).json(player);
}

export async function deletePlayerController(req: Request, res: Response) {
  await playersService.deletePlayer(req.params.id);
  res.status(200).json({ success: true });
}
