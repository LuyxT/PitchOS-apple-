import { Router } from 'express';
import { asyncHandler } from '../../middleware/asyncHandler';
import { authenticate } from '../../middleware/authMiddleware';
import * as ctrl from './calendar.controller';

export function calendarRoutes(jwtAccessSecret: string): Router {
  const router = Router();

  // Events
  router.get('/events', authenticate(jwtAccessSecret), asyncHandler(ctrl.listEventsController));
  router.post('/events', authenticate(jwtAccessSecret), asyncHandler(ctrl.createEventController));
  router.put('/events/:id', authenticate(jwtAccessSecret), asyncHandler(ctrl.updateEventController));
  router.delete('/events/:id', authenticate(jwtAccessSecret), asyncHandler(ctrl.deleteEventController));

  // Categories
  router.get('/categories', authenticate(jwtAccessSecret), asyncHandler(ctrl.listCategoriesController));
  router.post('/categories', authenticate(jwtAccessSecret), asyncHandler(ctrl.createCategoryController));

  return router;
}
