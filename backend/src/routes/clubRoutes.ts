import { Router } from 'express';
import { createClubController, getClubController } from '../controllers/clubController';
import { asyncHandler } from '../middleware/asyncHandler';
import { authMiddleware } from '../middleware/authMiddleware';

export function clubRouter(jwtSecret: string): Router {
  const router = Router();

  router.post('/', authMiddleware(jwtSecret), asyncHandler(createClubController));
  router.get('/:id', authMiddleware(jwtSecret), asyncHandler(getClubController));

  return router;
}
