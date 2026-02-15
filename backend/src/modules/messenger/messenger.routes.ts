import { Router } from 'express';
import { asyncHandler } from '../../middleware/asyncHandler';
import { authenticate } from '../../middleware/authMiddleware';
import * as ctrl from './messenger.controller';

export function messengerRoutes(jwtAccessSecret: string): Router {
  const router = Router();

  // Legacy threads endpoint
  router.get('/threads', authenticate(jwtAccessSecret), asyncHandler(ctrl.listThreads));

  // Chats
  router.get('/chats', authenticate(jwtAccessSecret), asyncHandler(ctrl.listChats));
  router.post('/chats/direct', authenticate(jwtAccessSecret), asyncHandler(ctrl.createDirectChat));
  router.post('/chats/group', authenticate(jwtAccessSecret), asyncHandler(ctrl.createGroupChat));
  router.patch('/chats/:chatId', authenticate(jwtAccessSecret), asyncHandler(ctrl.updateChat));
  router.post('/chats/:chatId/archive', authenticate(jwtAccessSecret), asyncHandler(ctrl.archiveChat));
  router.post('/chats/:chatId/unarchive', authenticate(jwtAccessSecret), asyncHandler(ctrl.unarchiveChat));

  // Messages
  router.get('/chats/:chatId/messages', authenticate(jwtAccessSecret), asyncHandler(ctrl.listMessages));
  router.post('/chats/:chatId/messages', authenticate(jwtAccessSecret), asyncHandler(ctrl.sendMessage));
  router.delete('/chats/:chatId/messages/:messageId', authenticate(jwtAccessSecret), asyncHandler(ctrl.deleteMessage));

  // Read receipts
  router.post('/chats/:chatId/read', authenticate(jwtAccessSecret), asyncHandler(ctrl.markRead));
  router.get('/chats/:chatId/read-receipts', authenticate(jwtAccessSecret), asyncHandler(ctrl.getReadReceipts));

  // Search
  router.get('/search', authenticate(jwtAccessSecret), asyncHandler(ctrl.searchMessages));

  // Media
  router.post('/media/register', authenticate(jwtAccessSecret), asyncHandler(ctrl.registerMedia));
  router.post('/media/:mediaId/complete', authenticate(jwtAccessSecret), asyncHandler(ctrl.completeMediaUpload));
  router.get('/media/:mediaId/download', authenticate(jwtAccessSecret), asyncHandler(ctrl.getMediaDownload));

  // Realtime
  router.get('/realtime/token', authenticate(jwtAccessSecret), asyncHandler(ctrl.realtimeToken));

  return router;
}
