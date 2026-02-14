import type { Request, Response } from 'express';
import { AppError } from '../../middleware/errorHandler';
import * as profilesService from './profiles.service';

export async function listProfiles(req: Request, res: Response) {
  if (!req.auth?.userId) {
    throw new AppError(401, 'UNAUTHORIZED', 'Unauthorized');
  }
  const profiles = await profilesService.listProfiles(req.auth.userId);
  res.status(200).json(profiles);
}

export async function createProfile(req: Request, res: Response) {
  if (!req.auth?.userId) {
    throw new AppError(401, 'UNAUTHORIZED', 'Unauthorized');
  }
  const profile = await profilesService.createProfile(req.auth.userId, req.body);
  res.status(201).json(profile);
}

export async function updateProfile(req: Request, res: Response) {
  if (!req.auth?.userId) {
    throw new AppError(401, 'UNAUTHORIZED', 'Unauthorized');
  }
  const profile = await profilesService.updateProfile(
    req.auth.userId,
    req.params.profileId,
    req.body,
  );
  res.status(200).json(profile);
}

export async function deleteProfile(req: Request, res: Response) {
  if (!req.auth?.userId) {
    throw new AppError(401, 'UNAUTHORIZED', 'Unauthorized');
  }
  await profilesService.deleteProfile(req.auth.userId, req.params.profileId);
  res.status(204).send();
}

export async function listAuditEntries(req: Request, res: Response) {
  if (!req.auth?.userId) {
    throw new AppError(401, 'UNAUTHORIZED', 'Unauthorized');
  }
  const profileId = typeof req.query.profileId === 'string' ? req.query.profileId : undefined;
  const entries = await profilesService.listAuditEntries(req.auth.userId, profileId);
  res.status(200).json(entries);
}
