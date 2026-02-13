import { Router } from 'express';
import { asyncHandler, validate } from '../../middleware/asyncHandler';
import { authenticate } from '../../middleware/authMiddleware';
import { updateProfileSchema } from './users.schema';
import * as ctrl from './users.controller';

export function usersRoutes(jwtAccessSecret: string): Router {
  const router = Router();

  router.get('/me', authenticate(jwtAccessSecret), asyncHandler(ctrl.getMeController));
  router.patch('/me', authenticate(jwtAccessSecret), validate(updateProfileSchema), asyncHandler(ctrl.updateProfileController));

  return router;
}
