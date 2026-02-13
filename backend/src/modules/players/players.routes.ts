import { Router } from 'express';
import { asyncHandler, validate } from '../../middleware/asyncHandler';
import { authenticate } from '../../middleware/authMiddleware';
import { createPlayerSchema } from './players.schema';
import * as ctrl from './players.controller';

export function playersRoutes(jwtAccessSecret: string): Router {
  const router = Router();

  router.post('/', authenticate(jwtAccessSecret), validate(createPlayerSchema), asyncHandler(ctrl.createPlayerController));
  router.get('/', authenticate(jwtAccessSecret), asyncHandler(ctrl.listPlayersController));
  router.get('/:id', authenticate(jwtAccessSecret), asyncHandler(ctrl.getPlayerController));
  router.delete('/:id', authenticate(jwtAccessSecret), asyncHandler(ctrl.deletePlayerController));

  return router;
}
