import { Router } from 'express';
import { asyncHandler, validate } from '../../middleware/asyncHandler';
import { authenticate } from '../../middleware/authMiddleware';
import { createTeamSchema } from './teams.schema';
import * as ctrl from './teams.controller';

export function teamsRoutes(jwtAccessSecret: string): Router {
  const router = Router();

  router.post('/', authenticate(jwtAccessSecret), validate(createTeamSchema), asyncHandler(ctrl.createTeamController));
  router.get('/', authenticate(jwtAccessSecret), asyncHandler(ctrl.listTeamsController));
  router.get('/:id', authenticate(jwtAccessSecret), asyncHandler(ctrl.getTeamController));

  return router;
}
