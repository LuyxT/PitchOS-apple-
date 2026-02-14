import { Router } from 'express';
import { asyncHandler, validate } from '../../middleware/asyncHandler';
import { authenticate } from '../../middleware/authMiddleware';
import { saveProfileSchema } from './profile.schema';
import * as ctrl from './profile.controller';

export function profileRoutes(jwtAccessSecret: string): Router {
  const router = Router();
  const auth = authenticate(jwtAccessSecret);

  router.get('/', auth, asyncHandler(ctrl.getProfileController));
  router.post('/', auth, validate(saveProfileSchema), asyncHandler(ctrl.saveProfileController));

  return router;
}
