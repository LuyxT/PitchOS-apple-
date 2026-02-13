import type { Request, Response } from 'express';
import { AppError } from '../../middleware/errorHandler';
import * as onboardingService from './onboarding.service';

export async function createClubController(req: Request, res: Response) {
  if (!req.auth?.userId) {
    throw new AppError(401, 'UNAUTHORIZED', 'Unauthorized');
  }
  const result = await onboardingService.createOnboardingClub(req.auth.userId, req.body);
  res.status(201).json(result);
}

export async function createTeamController(req: Request, res: Response) {
  if (!req.auth?.userId) {
    throw new AppError(401, 'UNAUTHORIZED', 'Unauthorized');
  }
  const result = await onboardingService.createOnboardingTeam(req.auth.userId, req.body);
  res.status(201).json(result);
}
