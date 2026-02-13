import { Router } from 'express';
import { asyncHandler, validate } from '../../middleware/asyncHandler';
import { authenticate } from '../../middleware/authMiddleware';
import { onboardingClubSchema, onboardingTeamSchema } from './onboarding.schema';
import * as ctrl from './onboarding.controller';

export function onboardingRoutes(jwtAccessSecret: string): Router {
  const router = Router();

  router.post('/club', authenticate(jwtAccessSecret), validate(onboardingClubSchema), asyncHandler(ctrl.createClubController));
  router.post('/team', authenticate(jwtAccessSecret), validate(onboardingTeamSchema), asyncHandler(ctrl.createTeamController));

  return router;
}
