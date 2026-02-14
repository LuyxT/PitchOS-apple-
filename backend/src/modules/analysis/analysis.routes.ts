import { Router } from 'express';
import express from 'express';
import { asyncHandler } from '../../middleware/asyncHandler';
import { authenticate } from '../../middleware/authMiddleware';
import * as ctrl from './analysis.controller';

export function analysisRoutes(jwtAccessSecret: string): Router {
  const router = Router();
  const auth = authenticate(jwtAccessSecret);
  const rawBody = express.raw({ type: '*/*', limit: '5gb' });

  // Categories
  router.get('/categories', auth, asyncHandler(ctrl.listCategories));
  router.post('/categories', auth, asyncHandler(ctrl.createCategory));

  // Videos
  router.post('/videos/register', auth, asyncHandler(ctrl.registerVideo));
  router.put('/videos/:videoId/upload', auth, rawBody, asyncHandler(ctrl.uploadVideoChunk));
  router.post('/videos/:videoId/complete', auth, asyncHandler(ctrl.completeVideoUpload));
  router.get('/videos/:videoId/playback', auth, asyncHandler(ctrl.getPlaybackURL));
  router.get('/videos/:videoId/stream', auth, asyncHandler(ctrl.streamVideo));

  // Sessions
  router.post('/sessions', auth, asyncHandler(ctrl.createSession));
  router.get('/sessions', auth, asyncHandler(ctrl.listSessions));
  router.get('/sessions/:sessionId', auth, asyncHandler(ctrl.getSession));

  // Markers
  router.post('/markers', auth, asyncHandler(ctrl.createMarker));
  router.put('/markers/:markerId', auth, asyncHandler(ctrl.updateMarker));
  router.delete('/markers/:markerId', auth, asyncHandler(ctrl.deleteMarker));

  // Clips
  router.post('/clips', auth, asyncHandler(ctrl.createClip));
  router.get('/clips', auth, asyncHandler(ctrl.listClips));
  router.put('/clips/:clipId', auth, asyncHandler(ctrl.updateClip));
  router.delete('/clips/:clipId', auth, asyncHandler(ctrl.deleteClip));
  router.post('/clips/:clipId/share', auth, asyncHandler(ctrl.shareClip));

  // Drawings
  router.put('/sessions/:sessionId/drawings', auth, asyncHandler(ctrl.saveDrawings));

  return router;
}
