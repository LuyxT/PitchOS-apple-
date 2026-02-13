import { Router } from 'express';
import {
  createPlayerController,
  deletePlayerController,
  listPlayersController,
} from '../controllers/playerController';
import { asyncHandler } from '../middleware/asyncHandler';
import { authMiddleware } from '../middleware/authMiddleware';

export function playerRouter(jwtSecret: string): Router {
  const router = Router();

  router.post('/', authMiddleware(jwtSecret), asyncHandler(createPlayerController));
  router.get('/', authMiddleware(jwtSecret), asyncHandler(listPlayersController));
  router.delete('/:id', authMiddleware(jwtSecret), asyncHandler(deletePlayerController));

  return router;
}
