import { Router } from 'express';
import { asyncHandler } from '../../middleware/asyncHandler';
import { authenticate } from '../../middleware/authMiddleware';
import * as ctrl from './analysis.controller';

export function analysisRoutes(jwtAccessSecret: string): Router {
  const router = Router();

  // Videos
  router.post('/videos/register', authenticate(jwtAccessSecret), asyncHandler(ctrl.registerVideo));
  router.post('/videos/:videoId/complete', authenticate(jwtAccessSecret), asyncHandler(ctrl.completeVideoUpload));
  router.get('/videos/:videoId/playback', authenticate(jwtAccessSecret), asyncHandler(ctrl.getPlaybackURL));

  // Sessions
  router.post('/sessions', authenticate(jwtAccessSecret), asyncHandler(ctrl.createSession));
  router.get('/sessions', authenticate(jwtAccessSecret), asyncHandler(ctrl.listSessions));
  router.get('/sessions/:sessionId', authenticate(jwtAccessSecret), asyncHandler(ctrl.getSession));

  // Markers
  router.post('/markers', authenticate(jwtAccessSecret), asyncHandler(ctrl.createMarker));
  router.put('/markers/:markerId', authenticate(jwtAccessSecret), asyncHandler(ctrl.updateMarker));
  router.delete('/markers/:markerId', authenticate(jwtAccessSecret), asyncHandler(ctrl.deleteMarker));

  // Clips
  router.post('/clips', authenticate(jwtAccessSecret), asyncHandler(ctrl.createClip));
  router.get('/clips', authenticate(jwtAccessSecret), asyncHandler(ctrl.listClips));
  router.put('/clips/:clipId', authenticate(jwtAccessSecret), asyncHandler(ctrl.updateClip));
  router.delete('/clips/:clipId', authenticate(jwtAccessSecret), asyncHandler(ctrl.deleteClip));
  router.post('/clips/:clipId/share', authenticate(jwtAccessSecret), asyncHandler(ctrl.shareClip));

  // Drawings
  router.put('/sessions/:sessionId/drawings', authenticate(jwtAccessSecret), asyncHandler(ctrl.saveDrawings));

  return router;
}
