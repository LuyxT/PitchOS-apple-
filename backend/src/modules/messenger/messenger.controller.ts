import type { Request, Response } from 'express';
import { AppError } from '../../middleware/errorHandler';
import * as svc from './messenger.service';
import { messengerHub } from './messenger.ws';

// ─── Helper ───────────────────────────────────────────

function requireAuth(req: Request): string {
  const userId = req.auth?.userId;
  if (!userId) {
    throw new AppError(401, 'UNAUTHORIZED', 'Unauthorized');
  }
  return userId;
}

// ─── Legacy threads ───────────────────────────────────

export async function listThreads(req: Request, res: Response): Promise<void> {
  requireAuth(req);
  res.status(200).json([]);
}

// ─── Chats ────────────────────────────────────────────

export async function listChats(req: Request, res: Response): Promise<void> {
  const userId = requireAuth(req);

  const limit = req.query.limit ? parseInt(req.query.limit as string, 10) : undefined;
  const cursor = typeof req.query.cursor === 'string' ? req.query.cursor : undefined;
  const archived = typeof req.query.archived === 'string' ? req.query.archived : undefined;
  const q = typeof req.query.q === 'string' ? req.query.q : undefined;

  const result = await svc.listChats({ userId, limit, cursor, archived, q });
  res.status(200).json(result);
}

export async function createDirectChat(req: Request, res: Response): Promise<void> {
  const userId = requireAuth(req);

  const { participantUserID } = req.body;
  if (!participantUserID) {
    throw new AppError(400, 'MISSING_PARTICIPANT', 'participantUserID is required');
  }

  const chat = await svc.createDirectChat(userId, participantUserID);
  res.status(201).json(chat);
}

export async function createGroupChat(req: Request, res: Response): Promise<void> {
  const userId = requireAuth(req);

  const { title, participantUserIDs, writePermission, temporaryUntil } = req.body;
  if (!title || !Array.isArray(participantUserIDs)) {
    throw new AppError(400, 'MISSING_FIELDS', 'title and participantUserIDs are required');
  }

  const chat = await svc.createGroupChat(userId, {
    title,
    participantUserIDs,
    writePermission,
    temporaryUntil,
  });
  res.status(201).json(chat);
}

export async function updateChat(req: Request, res: Response): Promise<void> {
  const userId = requireAuth(req);
  const { chatId } = req.params;

  const { writePermission, pinned, muted, title } = req.body;

  const chat = await svc.updateChat(chatId, userId, {
    writePermission,
    pinned,
    muted,
    title,
  });
  res.status(200).json(chat);
}

export async function archiveChat(req: Request, res: Response): Promise<void> {
  const userId = requireAuth(req);
  const { chatId } = req.params;

  const chat = await svc.archiveChat(chatId, userId);
  res.status(200).json(chat);
}

export async function unarchiveChat(req: Request, res: Response): Promise<void> {
  const userId = requireAuth(req);
  const { chatId } = req.params;

  const chat = await svc.unarchiveChat(chatId, userId);
  res.status(200).json(chat);
}

// ─── Messages ─────────────────────────────────────────

export async function listMessages(req: Request, res: Response): Promise<void> {
  const userId = requireAuth(req);
  const { chatId } = req.params;

  const limit = req.query.limit ? parseInt(req.query.limit as string, 10) : undefined;
  const cursor = typeof req.query.cursor === 'string' ? req.query.cursor : undefined;

  const result = await svc.listMessages({ chatId, userId, limit, cursor });
  res.status(200).json(result);
}

export async function sendMessage(req: Request, res: Response): Promise<void> {
  const userId = requireAuth(req);
  const { chatId } = req.params;

  const { type, text, contextLabel, attachmentID, clipReference } = req.body;

  const message = await svc.sendMessage(chatId, userId, {
    type,
    text,
    contextLabel,
    attachmentID,
    clipReference,
  });

  // Broadcast to all connected chat participants
  messengerHub.broadcastMessageCreated(chatId, message).catch(() => {});

  res.status(201).json(message);
}

export async function deleteMessage(req: Request, res: Response): Promise<void> {
  const userId = requireAuth(req);
  const { chatId, messageId } = req.params;

  await svc.deleteMessage(chatId, messageId, userId);

  // Broadcast deletion to all connected chat participants
  messengerHub.broadcastMessageDeleted(chatId, messageId).catch(() => {});

  res.status(200).json({ success: true });
}

// ─── Read receipts ────────────────────────────────────

export async function markRead(req: Request, res: Response): Promise<void> {
  const userId = requireAuth(req);
  const { chatId } = req.params;

  const { lastReadMessageID } = req.body;

  const result = await svc.markRead(chatId, userId, lastReadMessageID);
  res.status(200).json(result);
}

export async function getReadReceipts(req: Request, res: Response): Promise<void> {
  const userId = requireAuth(req);
  const { chatId } = req.params;

  const messageId = typeof req.query.messageId === 'string' ? req.query.messageId : undefined;

  const receipts = await svc.getReadReceipts(chatId, userId, messageId);
  res.status(200).json(receipts);
}

// ─── Search ───────────────────────────────────────────

export async function searchMessages(req: Request, res: Response): Promise<void> {
  const userId = requireAuth(req);

  const q = typeof req.query.q === 'string' ? req.query.q : '';
  const cursor = typeof req.query.cursor === 'string' ? req.query.cursor : undefined;
  const limit = req.query.limit ? parseInt(req.query.limit as string, 10) : undefined;
  const includeArchived = req.query.includeArchived === 'true';

  const result = await svc.search({ userId, q, cursor, limit, includeArchived });
  res.status(200).json(result);
}

// ─── Media ────────────────────────────────────────────

export async function registerMedia(req: Request, res: Response): Promise<void> {
  const userId = requireAuth(req);

  const { filename, mimeType, fileSize } = req.body;

  const result = svc.registerMedia(userId, { filename, mimeType, fileSize });
  res.status(201).json(result);
}

export async function completeMediaUpload(req: Request, res: Response): Promise<void> {
  requireAuth(req);
  const { mediaId } = req.params;

  const { checksum } = req.body;

  const result = svc.completeMediaUpload(mediaId, checksum);
  res.status(200).json(result);
}

export async function getMediaDownload(req: Request, res: Response): Promise<void> {
  requireAuth(req);
  const { mediaId } = req.params;

  const result = svc.getMediaDownload(mediaId);
  res.status(200).json(result);
}

// ─── Realtime token ──────────────────────────────────

export async function realtimeToken(req: Request, res: Response): Promise<void> {
  const userId = requireAuth(req);
  const auth = req.auth!;
  const secret = req.app.locals.env.JWT_ACCESS_SECRET as string;

  const result = messengerHub.generateRealtimeToken(userId, auth.email, auth.role, secret);
  res.status(200).json(result);
}
