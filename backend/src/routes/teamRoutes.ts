import { Router } from 'express';
import { createTeamController, getTeamController } from '../controllers/teamController';
import { asyncHandler } from '../middleware/asyncHandler';
import { authMiddleware } from '../middleware/authMiddleware';

export function teamRouter(jwtSecret: string): Router {
  const router = Router();

  router.post('/', authMiddleware(jwtSecret), asyncHandler(createTeamController));
  router.get('/:id', authMiddleware(jwtSecret), asyncHandler(getTeamController));

  return router;
}
