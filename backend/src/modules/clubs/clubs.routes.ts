import { Router } from 'express';
import { asyncHandler, validate } from '../../middleware/asyncHandler';
import { authenticate } from '../../middleware/authMiddleware';
import { createClubSchema } from './clubs.schema';
import * as ctrl from './clubs.controller';

export function clubsRoutes(jwtAccessSecret: string): Router {
  const router = Router();

  router.post('/', authenticate(jwtAccessSecret), validate(createClubSchema), asyncHandler(ctrl.createClubController));
  router.get('/', authenticate(jwtAccessSecret), asyncHandler(ctrl.listClubsController));
  router.get('/:id', authenticate(jwtAccessSecret), asyncHandler(ctrl.getClubController));

  return router;
}
