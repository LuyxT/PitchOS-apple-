import { Router } from 'express';
import { loginController, meController, registerController } from '../controllers/authController';
import { asyncHandler } from '../middleware/asyncHandler';
import { authMiddleware } from '../middleware/authMiddleware';

export function authRouter(jwtSecret: string): Router {
  const router = Router();

  router.post('/register', asyncHandler(registerController));
  router.post('/login', asyncHandler(loginController));
  router.get('/me', authMiddleware(jwtSecret), asyncHandler(meController));

  return router;
}
