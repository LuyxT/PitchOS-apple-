import { Router } from 'express';
import { asyncHandler } from '../../middleware/asyncHandler';
import { authenticate } from '../../middleware/authMiddleware';
import * as ctrl from './profiles.controller';

export function profilesRoutes(jwtAccessSecret: string): Router {
  const router = Router();

  router.get('/', authenticate(jwtAccessSecret), asyncHandler(ctrl.listProfiles));
  router.post('/', authenticate(jwtAccessSecret), asyncHandler(ctrl.createProfile));
  router.put('/:profileId', authenticate(jwtAccessSecret), asyncHandler(ctrl.updateProfile));
  router.delete('/:profileId', authenticate(jwtAccessSecret), asyncHandler(ctrl.deleteProfile));
  router.get('/audit', authenticate(jwtAccessSecret), asyncHandler(ctrl.listAuditEntries));

  return router;
}
