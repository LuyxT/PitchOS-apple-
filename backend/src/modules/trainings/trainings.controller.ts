import type { Request, Response } from 'express';
import { AppError } from '../../middleware/errorHandler';
import * as trainingsService from './trainings.service';

export async function createTrainingController(req: Request, res: Response) {
  if (!req.auth?.userId) {
    throw new AppError(401, 'UNAUTHORIZED', 'Unauthorized');
  }
  const training = await trainingsService.createTraining(req.body);
  res.status(201).json(training);
}

export async function listTrainingsController(req: Request, res: Response) {
  const teamId = typeof req.query.teamId === 'string' ? req.query.teamId : '';
  if (!teamId) {
    throw new AppError(400, 'MISSING_TEAM_ID', 'teamId query parameter is required');
  }
  const trainings = await trainingsService.listTrainings(teamId);
  res.status(200).json(trainings);
}

export async function getTrainingController(req: Request, res: Response) {
  const training = await trainingsService.getTrainingById(req.params.id);
  res.status(200).json(training);
}

export async function deleteTrainingController(req: Request, res: Response) {
  await trainingsService.deleteTraining(req.params.id);
  res.status(200).json({ success: true });
}
