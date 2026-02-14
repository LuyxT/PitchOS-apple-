import { Router } from 'express';
import { asyncHandler } from '../../middleware/asyncHandler';
import { authenticate } from '../../middleware/authMiddleware';
import * as ctrl from './feedback.controller';

export function feedbackRoutes(jwtAccessSecret: string): Router {
  const router = Router();

  router.get('/', authenticate(jwtAccessSecret), asyncHandler(ctrl.listFeedback));

  return router;
}
