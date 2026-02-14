import { Router } from 'express';
import express from 'express';
import { asyncHandler } from '../../middleware/asyncHandler';
import { authenticate } from '../../middleware/authMiddleware';
import * as ctrl from './cloud.controller';

export function cloudRoutes(jwtAccessSecret: string): Router {
  const router = Router();
  const auth = authenticate(jwtAccessSecret);
  const rawBody = express.raw({ type: '*/*', limit: '10mb' });

  // ─── Bootstrap ─────────────────────────────────────────
  router.get('/files/bootstrap', auth, asyncHandler(ctrl.bootstrap));

  // ─── File queries (must come before /files/:fileId) ────
  router.get('/files/largest', auth, asyncHandler(ctrl.largestFiles));
  router.get('/files/old', auth, asyncHandler(ctrl.oldFiles));
  router.get('/files', auth, asyncHandler(ctrl.listFiles));

  // ─── Folders ───────────────────────────────────────────
  router.post('/folders', auth, asyncHandler(ctrl.createFolder));
  router.put('/folders/:folderId', auth, asyncHandler(ctrl.updateFolder));

  // ─── File upload flow ──────────────────────────────────
  router.post('/files/register', auth, asyncHandler(ctrl.registerFile));
  router.put('/files/:fileId/upload', auth, rawBody, asyncHandler(ctrl.uploadChunk));
  router.post('/files/:fileId/complete', auth, asyncHandler(ctrl.completeUpload));

  // ─── File mutations ────────────────────────────────────
  router.patch('/files/:fileId', auth, asyncHandler(ctrl.updateFile));
  router.post('/files/:fileId/move', auth, asyncHandler(ctrl.moveFile));
  router.post('/files/:fileId/trash', auth, asyncHandler(ctrl.trashFile));
  router.post('/files/:fileId/restore', auth, asyncHandler(ctrl.restoreFile));
  router.delete('/files/:fileId', auth, asyncHandler(ctrl.deleteFile));

  return router;
}
