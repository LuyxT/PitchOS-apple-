import type { Request, Response } from 'express';
import { AppError } from '../middleware/errorHandler';
import { createPlayer, deletePlayer, listPlayers } from '../services/playerService';

export async function createPlayerController(req: Request, res: Response) {
  const name = typeof req.body?.name === 'string' ? req.body.name : '';
  const position = typeof req.body?.position === 'string' ? req.body.position : '';
  const age = Number(req.body?.age);
  const teamId = typeof req.body?.teamId === 'string' ? req.body.teamId : '';

  if (!teamId) {
    throw new AppError(400, 'INVALID_INPUT', 'teamId is required');
  }

  const player = await createPlayer({ name, position, age, teamId });
  res.status(201).json(player);
}

export async function listPlayersController(req: Request, res: Response) {
  const teamId = typeof req.query.teamId === 'string' ? req.query.teamId : undefined;
  const players = await listPlayers(teamId);
  res.status(200).json(players);
}

export async function deletePlayerController(req: Request, res: Response) {
  await deletePlayer(req.params.id);
  res.status(200).json({ success: true });
}
