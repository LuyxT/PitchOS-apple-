import { getPrisma } from '../../lib/prisma';
import { AppError } from '../../middleware/errorHandler';

// ─── DTOs ──────────────────────────────────────────────

export interface MessengerChatParticipantDTO {
  userID: string;
  displayName: string;
  role: string;
  playerID: string | null;
  mutedUntil: string | null;
  canWrite: boolean;
  joinedAt: string;
}

export interface MessengerChatDTO {
  id: string;
  title: string | null;
  type: string;
  participants: MessengerChatParticipantDTO[];
  lastMessagePreview: string | null;
  lastMessageAt: string | null;
  unreadCount: number;
  pinned: boolean;
  muted: boolean;
  archived: boolean;
  writePermission: string;
  temporaryUntil: string | null;
  createdAt: string;
  updatedAt: string;
}

export interface MessengerMessageDTO {
  id: string;
  chatID: string;
  senderUserID: string;
  senderName: string;
  type: string;
  text: string;
  contextLabel: string | null;
  attachment: {
    mediaID: string;
    kind: string;
    filename: string;
    mimeType: string;
    fileSize: number;
  } | null;
  clipReference: {
    clipID: string;
    analysisSessionID: string;
    videoAssetID: string;
    clipName: string;
    timeStart: number;
    timeEnd: number;
    matchID: string | null;
  } | null;
  status: string;
  readBy: { userID: string; userName: string; readAt: string }[];
  createdAt: string;
  updatedAt: string;
}

// ─── Helpers ──────────────────────────────────────────

function toParticipantDTO(p: {
  userId: string;
  displayName: string;
  role: string;
  playerID: string | null;
  mutedUntil: Date | null;
  canWrite: boolean;
  joinedAt: Date;
}): MessengerChatParticipantDTO {
  return {
    userID: p.userId,
    displayName: p.displayName,
    role: p.role,
    playerID: p.playerID,
    mutedUntil: p.mutedUntil ? p.mutedUntil.toISOString() : null,
    canWrite: p.canWrite,
    joinedAt: p.joinedAt.toISOString(),
  };
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
function toChatDTO(chat: any, userId: string): MessengerChatDTO {
  const participants = (chat.participants ?? []).map(toParticipantDTO);

  // Derive last message preview from the messages relation (if included)
  const lastMsg = chat.messages?.[0] ?? null;
  const lastMessagePreview = lastMsg ? lastMsg.text || null : null;
  const lastMessageAt = lastMsg ? lastMsg.createdAt.toISOString() : null;

  // Derive muted from the current user's participant record
  const selfParticipant = (chat.participants ?? []).find(
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    (p: any) => p.userId === userId
  );
  const muted = selfParticipant?.mutedUntil
    ? new Date(selfParticipant.mutedUntil) > new Date()
    : false;

  return {
    id: chat.id,
    title: chat.title ?? null,
    type: chat.type,
    participants,
    lastMessagePreview,
    lastMessageAt,
    unreadCount: 0,
    pinned: false,
    muted,
    archived: false,
    writePermission: chat.writePermission,
    temporaryUntil: chat.temporaryUntil ? chat.temporaryUntil.toISOString() : null,
    createdAt: chat.createdAt.toISOString(),
    updatedAt: chat.updatedAt.toISOString(),
  };
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
function toMessageDTO(msg: any): MessengerMessageDTO {
  return {
    id: msg.id,
    chatID: msg.chatId,
    senderUserID: msg.senderUserId,
    senderName: msg.senderName,
    type: msg.type,
    text: msg.text,
    contextLabel: msg.contextLabel ?? null,
    attachment: msg.attachment ?? null,
    clipReference: msg.clipReference ?? null,
    status: msg.status,
    readBy: Array.isArray(msg.readBy) ? msg.readBy : [],
    createdAt: msg.createdAt.toISOString(),
    updatedAt: msg.updatedAt.toISOString(),
  };
}

const CHAT_INCLUDE = {
  participants: true,
  messages: {
    orderBy: { createdAt: 'desc' as const },
    take: 1,
  },
};

// ─── List chats ───────────────────────────────────────

export interface ListChatsParams {
  userId: string;
  limit?: number;
  cursor?: string;
  archived?: string;
  q?: string;
}

export async function listChats(params: ListChatsParams): Promise<{
  items: MessengerChatDTO[];
  nextCursor: string | null;
}> {
  const prisma = getPrisma();
  const limit = params.limit ?? 30;

  // Find chats where the user is a participant
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const where: any = {
    participants: {
      some: { userId: params.userId },
    },
  };

  if (params.q) {
    where.OR = [
      { title: { contains: params.q, mode: 'insensitive' } },
      {
        messages: {
          some: { text: { contains: params.q, mode: 'insensitive' } },
        },
      },
    ];
  }

  // Build cursor condition
  if (params.cursor) {
    where.createdAt = { lt: new Date(params.cursor) };
  }

  const chats = await prisma.messengerChat.findMany({
    where,
    include: CHAT_INCLUDE,
    orderBy: { createdAt: 'desc' },
    take: limit + 1,
  });

  let nextCursor: string | null = null;
  if (chats.length > limit) {
    chats.pop();
    nextCursor = chats[chats.length - 1].createdAt.toISOString();
  }

  return {
    items: chats.map((c) => toChatDTO(c, params.userId)),
    nextCursor,
  };
}

// ─── Create direct chat ───────────────────────────────

export async function createDirectChat(
  userId: string,
  participantUserId: string
): Promise<MessengerChatDTO> {
  const prisma = getPrisma();

  if (userId === participantUserId) {
    throw new AppError(400, 'INVALID_PARTICIPANT', 'Cannot create a direct chat with yourself');
  }

  // Look up both users to get display names
  const [self, target] = await Promise.all([
    prisma.user.findUnique({ where: { id: userId } }),
    prisma.user.findUnique({ where: { id: participantUserId } }),
  ]);

  if (!target) {
    throw new AppError(404, 'USER_NOT_FOUND', 'Participant user not found');
  }

  // Check if a direct chat between these two users already exists
  const existing = await prisma.messengerChat.findFirst({
    where: {
      type: 'direct',
      AND: [
        { participants: { some: { userId } } },
        { participants: { some: { userId: participantUserId } } },
      ],
    },
    include: CHAT_INCLUDE,
  });

  if (existing) {
    return toChatDTO(existing, userId);
  }

  const selfName = self
    ? [self.firstName, self.lastName].filter(Boolean).join(' ') || 'Unknown'
    : 'Unknown';
  const targetName = [target.firstName, target.lastName].filter(Boolean).join(' ') || 'Unknown';

  const chat = await prisma.messengerChat.create({
    data: {
      type: 'direct',
      participants: {
        create: [
          { userId, displayName: selfName, role: self?.role ?? 'member' },
          { userId: participantUserId, displayName: targetName, role: target.role ?? 'member' },
        ],
      },
    },
    include: CHAT_INCLUDE,
  });

  return toChatDTO(chat, userId);
}

// ─── Create group chat ────────────────────────────────

export interface CreateGroupChatInput {
  title: string;
  participantUserIDs: string[];
  writePermission?: string;
  temporaryUntil?: string;
}

export async function createGroupChat(
  userId: string,
  input: CreateGroupChatInput
): Promise<MessengerChatDTO> {
  const prisma = getPrisma();

  if (!input.title) {
    throw new AppError(400, 'MISSING_TITLE', 'Group chat title is required');
  }

  // Collect all unique user IDs (creator + participants)
  const allUserIds = Array.from(new Set([userId, ...input.participantUserIDs]));

  // Look up all users
  const users = await prisma.user.findMany({
    where: { id: { in: allUserIds } },
  });

  const userMap = new Map(users.map((u) => [u.id, u]));

  const chat = await prisma.messengerChat.create({
    data: {
      title: input.title,
      type: 'group',
      writePermission: input.writePermission ?? 'all_members',
      temporaryUntil: input.temporaryUntil ? new Date(input.temporaryUntil) : null,
      participants: {
        create: allUserIds.map((uid) => {
          const user = userMap.get(uid);
          const displayName = user
            ? [user.firstName, user.lastName].filter(Boolean).join(' ') || 'Unknown'
            : 'Unknown';
          return {
            userId: uid,
            displayName,
            role: user?.role ?? 'member',
          };
        }),
      },
    },
    include: CHAT_INCLUDE,
  });

  return toChatDTO(chat, userId);
}

// ─── Update chat ──────────────────────────────────────

export interface UpdateChatInput {
  writePermission?: string;
  pinned?: boolean;
  muted?: boolean;
  title?: string;
}

export async function updateChat(
  chatId: string,
  userId: string,
  input: UpdateChatInput
): Promise<MessengerChatDTO> {
  const prisma = getPrisma();

  const chat = await prisma.messengerChat.findUnique({
    where: { id: chatId },
    include: { participants: true },
  });

  if (!chat) {
    throw new AppError(404, 'CHAT_NOT_FOUND', 'Chat not found');
  }

  const isParticipant = chat.participants.some((p) => p.userId === userId);
  if (!isParticipant) {
    throw new AppError(403, 'FORBIDDEN', 'You are not a participant in this chat');
  }

  // Update chat-level fields
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const chatUpdate: any = {};
  if (input.writePermission !== undefined) chatUpdate.writePermission = input.writePermission;
  if (input.title !== undefined) chatUpdate.title = input.title;

  if (Object.keys(chatUpdate).length > 0) {
    await prisma.messengerChat.update({
      where: { id: chatId },
      data: chatUpdate,
    });
  }

  // Update participant-level fields (muted)
  if (input.muted !== undefined) {
    const mutedUntil = input.muted ? new Date('2099-12-31T23:59:59Z') : null;
    await prisma.messengerParticipant.updateMany({
      where: { chatId, userId },
      data: { mutedUntil },
    });
  }

  const updated = await prisma.messengerChat.findUnique({
    where: { id: chatId },
    include: CHAT_INCLUDE,
  });

  return toChatDTO(updated!, userId);
}

// ─── Archive / Unarchive chat ─────────────────────────

export async function archiveChat(
  chatId: string,
  userId: string
): Promise<MessengerChatDTO> {
  const prisma = getPrisma();

  const chat = await prisma.messengerChat.findUnique({
    where: { id: chatId },
    include: { participants: true },
  });

  if (!chat) {
    throw new AppError(404, 'CHAT_NOT_FOUND', 'Chat not found');
  }

  const isParticipant = chat.participants.some((p) => p.userId === userId);
  if (!isParticipant) {
    throw new AppError(403, 'FORBIDDEN', 'You are not a participant in this chat');
  }

  const full = await prisma.messengerChat.findUnique({
    where: { id: chatId },
    include: CHAT_INCLUDE,
  });

  const dto = toChatDTO(full!, userId);
  dto.archived = true;
  return dto;
}

export async function unarchiveChat(
  chatId: string,
  userId: string
): Promise<MessengerChatDTO> {
  const prisma = getPrisma();

  const chat = await prisma.messengerChat.findUnique({
    where: { id: chatId },
    include: { participants: true },
  });

  if (!chat) {
    throw new AppError(404, 'CHAT_NOT_FOUND', 'Chat not found');
  }

  const isParticipant = chat.participants.some((p) => p.userId === userId);
  if (!isParticipant) {
    throw new AppError(403, 'FORBIDDEN', 'You are not a participant in this chat');
  }

  const full = await prisma.messengerChat.findUnique({
    where: { id: chatId },
    include: CHAT_INCLUDE,
  });

  const dto = toChatDTO(full!, userId);
  dto.archived = false;
  return dto;
}

// ─── List messages ────────────────────────────────────

export interface ListMessagesParams {
  chatId: string;
  userId: string;
  limit?: number;
  cursor?: string;
}

export async function listMessages(params: ListMessagesParams): Promise<{
  items: MessengerMessageDTO[];
  nextCursor: string | null;
}> {
  const prisma = getPrisma();
  const limit = params.limit ?? 50;

  // Verify the user is a participant
  const participant = await prisma.messengerParticipant.findFirst({
    where: { chatId: params.chatId, userId: params.userId },
  });

  if (!participant) {
    throw new AppError(403, 'FORBIDDEN', 'You are not a participant in this chat');
  }

  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const where: any = { chatId: params.chatId };

  if (params.cursor) {
    where.createdAt = { lt: new Date(params.cursor) };
  }

  const messages = await prisma.messengerMessage.findMany({
    where,
    orderBy: { createdAt: 'desc' },
    take: limit + 1,
  });

  let nextCursor: string | null = null;
  if (messages.length > limit) {
    messages.pop();
    nextCursor = messages[messages.length - 1].createdAt.toISOString();
  }

  return {
    items: messages.map(toMessageDTO),
    nextCursor,
  };
}

// ─── Send message ─────────────────────────────────────

export interface SendMessageInput {
  type?: string;
  text?: string;
  contextLabel?: string;
  attachmentID?: string;
  clipReference?: {
    clipID: string;
    analysisSessionID: string;
    videoAssetID: string;
    clipName: string;
    timeStart: number;
    timeEnd: number;
    matchID?: string | null;
  };
}

export async function sendMessage(
  chatId: string,
  userId: string,
  input: SendMessageInput
): Promise<MessengerMessageDTO> {
  const prisma = getPrisma();

  // Verify the user is a participant
  const participant = await prisma.messengerParticipant.findFirst({
    where: { chatId, userId },
  });

  if (!participant) {
    throw new AppError(403, 'FORBIDDEN', 'You are not a participant in this chat');
  }

  if (!participant.canWrite) {
    throw new AppError(403, 'WRITE_DENIED', 'You do not have write permission in this chat');
  }

  // Build attachment JSON if provided
  let attachment = null;
  if (input.attachmentID) {
    attachment = {
      mediaID: input.attachmentID,
      kind: 'file',
      filename: '',
      mimeType: '',
      fileSize: 0,
    };
  }

  const message = await prisma.messengerMessage.create({
    data: {
      chatId,
      senderUserId: userId,
      senderName: participant.displayName,
      type: input.type ?? 'text',
      text: input.text ?? '',
      contextLabel: input.contextLabel ?? null,
      attachment: attachment ?? undefined,
      clipReference: input.clipReference ?? undefined,
      status: 'sent',
      readBy: [],
    },
  });

  // Touch the chat's updatedAt
  await prisma.messengerChat.update({
    where: { id: chatId },
    data: { updatedAt: new Date() },
  });

  return toMessageDTO(message);
}

// ─── Delete message ───────────────────────────────────

export async function deleteMessage(
  chatId: string,
  messageId: string,
  userId: string
): Promise<void> {
  const prisma = getPrisma();

  const message = await prisma.messengerMessage.findUnique({
    where: { id: messageId },
  });

  if (!message) {
    throw new AppError(404, 'MESSAGE_NOT_FOUND', 'Message not found');
  }

  if (message.chatId !== chatId) {
    throw new AppError(404, 'MESSAGE_NOT_FOUND', 'Message not found in this chat');
  }

  if (message.senderUserId !== userId) {
    throw new AppError(403, 'FORBIDDEN', 'You can only delete your own messages');
  }

  await prisma.messengerMessage.delete({
    where: { id: messageId },
  });
}

// ─── Mark read ────────────────────────────────────────

export async function markRead(
  chatId: string,
  userId: string,
  lastReadMessageId?: string
): Promise<{ success: true }> {
  const prisma = getPrisma();

  // Verify user is a participant
  const participant = await prisma.messengerParticipant.findFirst({
    where: { chatId, userId },
  });

  if (!participant) {
    throw new AppError(403, 'FORBIDDEN', 'You are not a participant in this chat');
  }

  // If a specific message ID is given, update readBy on that message
  if (lastReadMessageId) {
    const message = await prisma.messengerMessage.findUnique({
      where: { id: lastReadMessageId },
    });

    if (message && message.chatId === chatId) {
      const readBy = Array.isArray(message.readBy) ? (message.readBy as { userID: string }[]) : [];
      const alreadyRead = readBy.some((r) => r.userID === userId);

      if (!alreadyRead) {
        await prisma.messengerMessage.update({
          where: { id: lastReadMessageId },
          data: {
            readBy: [
              ...readBy,
              {
                userID: userId,
                userName: participant.displayName,
                readAt: new Date().toISOString(),
              },
            ],
          },
        });
      }
    }
  }

  return { success: true };
}

// ─── Read receipts ────────────────────────────────────

export async function getReadReceipts(
  chatId: string,
  userId: string,
  messageId?: string
): Promise<{ userID: string; userName: string; readAt: string }[]> {
  const prisma = getPrisma();

  // Verify user is a participant
  const participant = await prisma.messengerParticipant.findFirst({
    where: { chatId, userId },
  });

  if (!participant) {
    throw new AppError(403, 'FORBIDDEN', 'You are not a participant in this chat');
  }

  if (!messageId) {
    return [];
  }

  const message = await prisma.messengerMessage.findUnique({
    where: { id: messageId },
  });

  if (!message || message.chatId !== chatId) {
    return [];
  }

  const readBy = Array.isArray(message.readBy) ? message.readBy : [];
  return readBy as { userID: string; userName: string; readAt: string }[];
}

// ─── Search ───────────────────────────────────────────

export interface SearchParams {
  userId: string;
  q: string;
  cursor?: string;
  limit?: number;
  includeArchived?: boolean;
}

export async function search(params: SearchParams): Promise<{
  items: {
    type: string;
    chatID?: string;
    messageID?: string;
    title: string;
    subtitle: string;
    occurredAt: string;
  }[];
  nextCursor: string | null;
}> {
  const prisma = getPrisma();
  const limit = params.limit ?? 20;

  if (!params.q || params.q.trim().length === 0) {
    return { items: [], nextCursor: null };
  }

  // Search messages in chats where user is a participant
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const where: any = {
    text: { contains: params.q, mode: 'insensitive' },
    chat: {
      participants: {
        some: { userId: params.userId },
      },
    },
  };

  if (params.cursor) {
    where.createdAt = { lt: new Date(params.cursor) };
  }

  const messages = await prisma.messengerMessage.findMany({
    where,
    include: { chat: true },
    orderBy: { createdAt: 'desc' },
    take: limit + 1,
  });

  let nextCursor: string | null = null;
  if (messages.length > limit) {
    messages.pop();
    nextCursor = messages[messages.length - 1].createdAt.toISOString();
  }

  const items = messages.map((msg) => ({
    type: 'message' as const,
    chatID: msg.chatId,
    messageID: msg.id,
    title: msg.senderName,
    subtitle: msg.text.length > 80 ? msg.text.slice(0, 80) + '...' : msg.text,
    occurredAt: msg.createdAt.toISOString(),
  }));

  return { items, nextCursor };
}

// ─── Media ────────────────────────────────────────────

export interface RegisterMediaInput {
  filename: string;
  mimeType: string;
  fileSize: number;
}

export function registerMedia(
  _userId: string,
  input: RegisterMediaInput
): { mediaID: string; uploadURL: string; headers: Record<string, string> } {
  if (!input.filename || !input.mimeType) {
    throw new AppError(400, 'MISSING_FIELDS', 'filename and mimeType are required');
  }

  // Generate a placeholder media ID
  const mediaID = `media_${Date.now()}_${Math.random().toString(36).slice(2, 10)}`;

  return {
    mediaID,
    uploadURL: '/placeholder',
    headers: {},
  };
}

export function completeMediaUpload(
  mediaId: string,
  _checksum?: string
): { mediaID: string; status: string } {
  return {
    mediaID: mediaId,
    status: 'ready',
  };
}

export function getMediaDownload(
  mediaId: string
): { downloadURL: string; expiresAt: string } {
  const expiresAt = new Date(Date.now() + 60 * 60 * 1000); // 1 hour

  return {
    downloadURL: '/placeholder',
    expiresAt: expiresAt.toISOString(),
  };
}
