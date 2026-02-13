import { Router } from 'express';
import { asyncHandler } from '../../middleware/asyncHandler';
import * as ctrl from './health.controller';

export function healthRoutes(): Router {
  const router = Router();

  router.get('/health', asyncHandler(ctrl.healthCheck));
  router.get('/', asyncHandler(ctrl.healthCheck));

  return router;
}
