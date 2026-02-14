import { Router } from 'express';
import { asyncHandler } from '../../middleware/asyncHandler';
import { authenticate } from '../../middleware/authMiddleware';
import * as ctrl from './admin.controller';

export function adminRoutes(jwtAccessSecret: string): Router {
  const router = Router();

  // Tasks
  router.get('/tasks', authenticate(jwtAccessSecret), asyncHandler(ctrl.listTasksController));

  // Bootstrap
  router.get('/bootstrap', authenticate(jwtAccessSecret), asyncHandler(ctrl.getBootstrapController));

  // Persons
  router.post('/persons', authenticate(jwtAccessSecret), asyncHandler(ctrl.createPersonController));
  router.put('/persons/:personId', authenticate(jwtAccessSecret), asyncHandler(ctrl.updatePersonController));
  router.delete('/persons/:personId', authenticate(jwtAccessSecret), asyncHandler(ctrl.deletePersonController));

  // Groups
  router.post('/groups', authenticate(jwtAccessSecret), asyncHandler(ctrl.createGroupController));
  router.put('/groups/:groupId', authenticate(jwtAccessSecret), asyncHandler(ctrl.updateGroupController));
  router.delete('/groups/:groupId', authenticate(jwtAccessSecret), asyncHandler(ctrl.deleteGroupController));

  // Invitations
  router.post('/invitations', authenticate(jwtAccessSecret), asyncHandler(ctrl.createInvitationController));
  router.put('/invitations/:invitationId/status', authenticate(jwtAccessSecret), asyncHandler(ctrl.updateInvitationStatusController));
  router.post('/invitations/:invitationId/resend', authenticate(jwtAccessSecret), asyncHandler(ctrl.resendInvitationController));

  // Audit
  router.get('/audit', authenticate(jwtAccessSecret), asyncHandler(ctrl.listAuditController));

  // Seasons
  router.post('/seasons', authenticate(jwtAccessSecret), asyncHandler(ctrl.createSeasonController));
  router.put('/seasons/:seasonId', authenticate(jwtAccessSecret), asyncHandler(ctrl.updateSeasonController));
  router.put('/seasons/:seasonId/status', authenticate(jwtAccessSecret), asyncHandler(ctrl.updateSeasonStatusController));
  router.post('/seasons/activate', authenticate(jwtAccessSecret), asyncHandler(ctrl.activateSeasonController));
  router.post('/seasons/:seasonId/duplicate-roster', authenticate(jwtAccessSecret), asyncHandler(ctrl.duplicateRosterController));

  // Settings
  router.put('/settings/club', authenticate(jwtAccessSecret), asyncHandler(ctrl.saveClubSettingsController));
  router.put('/settings/messenger', authenticate(jwtAccessSecret), asyncHandler(ctrl.saveMessengerRulesController));

  return router;
}
