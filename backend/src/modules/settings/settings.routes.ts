import { Router } from 'express';
import { asyncHandler } from '../../middleware/asyncHandler';
import { authenticate } from '../../middleware/authMiddleware';
import * as ctrl from './settings.controller';

export function settingsRoutes(jwtAccessSecret: string): Router {
  const router = Router();

  // Bootstrap — aggregated settings
  router.get('/bootstrap', authenticate(jwtAccessSecret), asyncHandler(ctrl.getBootstrapController));

  // Presentation
  router.put('/presentation', authenticate(jwtAccessSecret), asyncHandler(ctrl.savePresentationController));

  // Notifications
  router.put('/notifications', authenticate(jwtAccessSecret), asyncHandler(ctrl.saveNotificationsController));

  // Security
  router.get('/security', authenticate(jwtAccessSecret), asyncHandler(ctrl.getSecurityController));
  router.post('/security/password', authenticate(jwtAccessSecret), asyncHandler(ctrl.changePasswordController));
  router.post('/security/two-factor', authenticate(jwtAccessSecret), asyncHandler(ctrl.updateTwoFactorController));
  router.post('/security/sessions/revoke', authenticate(jwtAccessSecret), asyncHandler(ctrl.revokeSessionController));
  router.post('/security/sessions/revoke-all', authenticate(jwtAccessSecret), asyncHandler(ctrl.revokeAllSessionsController));

  // App info
  router.get('/app-info', authenticate(jwtAccessSecret), asyncHandler(ctrl.getAppInfoController));

  // Feedback
  router.post('/feedback', authenticate(jwtAccessSecret), asyncHandler(ctrl.submitFeedbackController));

  // Account
  router.post('/account/context', authenticate(jwtAccessSecret), asyncHandler(ctrl.switchAccountContextController));
  router.post('/account/deactivate', authenticate(jwtAccessSecret), asyncHandler(ctrl.deactivateAccountController));
  router.post('/account/leave-team', authenticate(jwtAccessSecret), asyncHandler(ctrl.leaveTeamController));

  return router;
}
