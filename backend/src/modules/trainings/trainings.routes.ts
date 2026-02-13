import { Router } from 'express';
import { asyncHandler, validate } from '../../middleware/asyncHandler';
import { authenticate } from '../../middleware/authMiddleware';
import { createTrainingSchema } from './trainings.schema';
import * as ctrl from './trainings.controller';

export function trainingsRoutes(jwtAccessSecret: string): Router {
  const router = Router();

  router.post('/', authenticate(jwtAccessSecret), validate(createTrainingSchema), asyncHandler(ctrl.createTrainingController));
  router.get('/', authenticate(jwtAccessSecret), asyncHandler(ctrl.listTrainingsController));
  router.get('/:id', authenticate(jwtAccessSecret), asyncHandler(ctrl.getTrainingController));
  router.delete('/:id', authenticate(jwtAccessSecret), asyncHandler(ctrl.deleteTrainingController));

  return router;
}
