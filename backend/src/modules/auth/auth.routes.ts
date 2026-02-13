import { Router } from 'express';
import { asyncHandler, validate } from '../../middleware/asyncHandler';
import { authenticate } from '../../middleware/authMiddleware';
import { registerSchema, loginSchema, refreshSchema } from './auth.schema';
import * as ctrl from './auth.controller';

export function authRoutes(jwtAccessSecret: string): Router {
  const router = Router();

  router.post('/register', validate(registerSchema), asyncHandler(ctrl.registerController));
  router.post('/login', validate(loginSchema), asyncHandler(ctrl.loginController));
  router.post('/refresh', validate(refreshSchema), asyncHandler(ctrl.refreshController));
  router.get('/me', authenticate(jwtAccessSecret), asyncHandler(ctrl.meController));
  router.post('/logout', authenticate(jwtAccessSecret), asyncHandler(ctrl.logoutController));

  return router;
}
