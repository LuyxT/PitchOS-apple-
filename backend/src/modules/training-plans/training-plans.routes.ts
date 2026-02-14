import { Router } from 'express';
import { asyncHandler } from '../../middleware/asyncHandler';
import { authenticate } from '../../middleware/authMiddleware';
import * as ctrl from './training-plans.controller';

export function trainingPlansRoutes(jwtAccessSecret: string): Router {
  const router = Router();

  // ─── Plans CRUD ─────────────────────────────────────────
  router.get('/plans', authenticate(jwtAccessSecret), asyncHandler(ctrl.listPlansController));
  router.get('/plans/:planId', authenticate(jwtAccessSecret), asyncHandler(ctrl.getPlanController));
  router.post('/plans', authenticate(jwtAccessSecret), asyncHandler(ctrl.createPlanController));
  router.put('/plans/:planId', authenticate(jwtAccessSecret), asyncHandler(ctrl.updatePlanController));
  router.delete('/plans/:planId', authenticate(jwtAccessSecret), asyncHandler(ctrl.deletePlanController));

  // ─── Phases & Exercises ─────────────────────────────────
  router.put('/plans/:planId/phases', authenticate(jwtAccessSecret), asyncHandler(ctrl.savePhasesController));
  router.put('/plans/:planId/exercises', authenticate(jwtAccessSecret), asyncHandler(ctrl.saveExercisesController));

  // ─── Exercise Templates ─────────────────────────────────
  router.post('/templates', authenticate(jwtAccessSecret), asyncHandler(ctrl.createTemplateController));
  router.get('/templates', authenticate(jwtAccessSecret), asyncHandler(ctrl.listTemplatesController));

  // ─── Groups & Briefings ─────────────────────────────────
  router.post('/plans/:planId/groups', authenticate(jwtAccessSecret), asyncHandler(ctrl.createGroupController));
  router.put('/groups/:groupId', authenticate(jwtAccessSecret), asyncHandler(ctrl.updateGroupController));
  router.put('/groups/:groupId/briefing', authenticate(jwtAccessSecret), asyncHandler(ctrl.saveGroupBriefingController));

  // ─── Participants / Availability ────────────────────────
  router.put('/plans/:planId/participants', authenticate(jwtAccessSecret), asyncHandler(ctrl.saveParticipantsController));

  // ─── Live Mode ──────────────────────────────────────────
  router.post('/plans/:planId/live/start', authenticate(jwtAccessSecret), asyncHandler(ctrl.startLiveController));
  router.put('/plans/:planId/live/state', authenticate(jwtAccessSecret), asyncHandler(ctrl.saveLiveStateController));
  router.post('/plans/:planId/live/deviations', authenticate(jwtAccessSecret), asyncHandler(ctrl.createDeviationController));

  // ─── Report ─────────────────────────────────────────────
  router.post('/plans/:planId/report', authenticate(jwtAccessSecret), asyncHandler(ctrl.saveReportController));
  router.get('/plans/:planId/report', authenticate(jwtAccessSecret), asyncHandler(ctrl.getReportController));

  // ─── Calendar Link ──────────────────────────────────────
  router.post('/plans/:planId/calendar-link', authenticate(jwtAccessSecret), asyncHandler(ctrl.linkCalendarController));

  // ─── Duplicate ──────────────────────────────────────────
  router.post('/plans/:planId/duplicate', authenticate(jwtAccessSecret), asyncHandler(ctrl.duplicatePlanController));

  return router;
}
