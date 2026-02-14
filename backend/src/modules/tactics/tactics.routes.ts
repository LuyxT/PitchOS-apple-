import { Router } from 'express';
import { asyncHandler } from '../../middleware/asyncHandler';
import { authenticate } from '../../middleware/authMiddleware';
import * as ctrl from './tactics.controller';

export function tacticsRoutes(jwtAccessSecret: string): Router {
  const router = Router();

  router.get('/', authenticate(jwtAccessSecret), asyncHandler(ctrl.listTacticBoards));
  router.get('/state', authenticate(jwtAccessSecret), asyncHandler(ctrl.getTacticsState));
  router.put('/state', authenticate(jwtAccessSecret), asyncHandler(ctrl.saveTacticsState));

  return router;
}
