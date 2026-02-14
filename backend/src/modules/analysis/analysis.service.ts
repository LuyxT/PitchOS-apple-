import { getPrisma } from '../../lib/prisma';
import { AppError } from '../../middleware/errorHandler';

/* ── DTO mappers ── */

function toSessionDTO(s: {
  id: string;
  videoId: string;
  title: string;
  matchId: string | null;
  teamId: string | null;
  userId: string;
  createdAt: Date;
  updatedAt: Date;
}) {
  return {
    id: s.id,
    videoId: s.videoId,
    title: s.title,
    matchId: s.matchId,
    teamId: s.teamId,
    userId: s.userId,
    createdAt: s.createdAt.toISOString(),
    updatedAt: s.updatedAt.toISOString(),
  };
}

function toMarkerDTO(m: {
  id: string;
  sessionId: string;
  videoId: string;
  timeSeconds: number;
  categoryId: string | null;
  comment: string | null;
  playerID: string | null;
  userId: string;
  createdAt: Date;
  updatedAt: Date;
}) {
  return {
    id: m.id,
    sessionId: m.sessionId,
    videoId: m.videoId,
    timeSeconds: m.timeSeconds,
    categoryId: m.categoryId,
    comment: m.comment,
    playerID: m.playerID,
    userId: m.userId,
    createdAt: m.createdAt.toISOString(),
    updatedAt: m.updatedAt.toISOString(),
  };
}

function toClipDTO(c: {
  id: string;
  sessionId: string;
  videoId: string;
  name: string;
  startSeconds: number;
  endSeconds: number;
  playerIDs: unknown;
  note: string | null;
  userId: string;
  createdAt: Date;
  updatedAt: Date;
}) {
  return {
    id: c.id,
    sessionId: c.sessionId,
    videoId: c.videoId,
    name: c.name,
    startSeconds: c.startSeconds,
    endSeconds: c.endSeconds,
    playerIDs: c.playerIDs,
    note: c.note,
    userId: c.userId,
    createdAt: c.createdAt.toISOString(),
    updatedAt: c.updatedAt.toISOString(),
  };
}

function toDrawingDTO(d: {
  id: string;
  sessionId: string;
  localId: string | null;
  tool: string;
  points: unknown;
  colorHex: string;
  isTemporary: boolean;
  timeSeconds: number | null;
  userId: string;
  createdAt: Date;
  updatedAt: Date;
}) {
  return {
    id: d.id,
    sessionId: d.sessionId,
    localId: d.localId,
    tool: d.tool,
    points: d.points,
    colorHex: d.colorHex,
    isTemporary: d.isTemporary,
    timeSeconds: d.timeSeconds,
    userId: d.userId,
    createdAt: d.createdAt.toISOString(),
    updatedAt: d.updatedAt.toISOString(),
  };
}

/* ── Videos ── */

export async function registerVideo(
  userId: string,
  input: { filename: string; fileSize: number; mimeType: string; sha256?: string },
) {
  const prisma = getPrisma();

  const video = await prisma.analysisVideo.create({
    data: {
      userId,
      filename: input.filename,
      fileSize: input.fileSize,
      mimeType: input.mimeType,
      sha256: input.sha256 ?? null,
    },
  });

  return {
    id: video.id,
    uploadURL: '/placeholder',
    headers: {},
  };
}

export async function completeVideoUpload(
  userId: string,
  videoId: string,
  input: { playbackURL?: string },
) {
  const prisma = getPrisma();

  const video = await prisma.analysisVideo.findUnique({ where: { id: videoId } });
  if (!video || video.userId !== userId) {
    throw new AppError(404, 'VIDEO_NOT_FOUND', 'Video not found');
  }

  const updated = await prisma.analysisVideo.update({
    where: { id: videoId },
    data: {
      importedAt: new Date(),
      playbackURL: input.playbackURL ?? video.playbackURL,
    },
  });

  return {
    id: updated.id,
    playbackURL: updated.playbackURL,
  };
}

export async function getPlaybackURL(userId: string, videoId: string) {
  const prisma = getPrisma();

  const video = await prisma.analysisVideo.findUnique({ where: { id: videoId } });
  if (!video || video.userId !== userId) {
    throw new AppError(404, 'VIDEO_NOT_FOUND', 'Video not found');
  }

  const expiresAt = new Date(Date.now() + 60 * 60 * 1000); // 1 hour from now

  return {
    signedURL: video.playbackURL ?? '/placeholder',
    expiresAt: expiresAt.toISOString(),
  };
}

/* ── Sessions ── */

export async function createSession(
  userId: string,
  input: { videoId: string; title: string; matchId?: string; teamId?: string },
) {
  const prisma = getPrisma();

  const session = await prisma.analysisSession.create({
    data: {
      userId,
      videoId: input.videoId,
      title: input.title,
      matchId: input.matchId ?? null,
      teamId: input.teamId ?? null,
    },
  });

  return toSessionDTO(session);
}

export async function listSessions(userId: string) {
  const prisma = getPrisma();

  const sessions = await prisma.analysisSession.findMany({
    where: { userId },
    orderBy: { createdAt: 'desc' },
  });

  return sessions.map(toSessionDTO);
}

export async function getSession(userId: string, sessionId: string) {
  const prisma = getPrisma();

  const session = await prisma.analysisSession.findUnique({ where: { id: sessionId } });
  if (!session || session.userId !== userId) {
    throw new AppError(404, 'SESSION_NOT_FOUND', 'Session not found');
  }

  const [markers, clips, drawings] = await Promise.all([
    prisma.analysisMarker.findMany({
      where: { sessionId },
      orderBy: { timeSeconds: 'asc' },
    }),
    prisma.analysisClip.findMany({
      where: { sessionId },
      orderBy: { startSeconds: 'asc' },
    }),
    prisma.analysisDrawing.findMany({
      where: { sessionId },
      orderBy: { createdAt: 'asc' },
    }),
  ]);

  return {
    session: toSessionDTO(session),
    markers: markers.map(toMarkerDTO),
    clips: clips.map(toClipDTO),
    drawings: drawings.map(toDrawingDTO),
  };
}

/* ── Markers ── */

export async function createMarker(
  userId: string,
  input: {
    sessionId: string;
    videoId: string;
    timeSeconds: number;
    categoryId?: string;
    comment?: string;
    playerID?: string;
  },
) {
  const prisma = getPrisma();

  const marker = await prisma.analysisMarker.create({
    data: {
      userId,
      sessionId: input.sessionId,
      videoId: input.videoId,
      timeSeconds: input.timeSeconds,
      categoryId: input.categoryId ?? null,
      comment: input.comment ?? null,
      playerID: input.playerID ?? null,
    },
  });

  return toMarkerDTO(marker);
}

export async function updateMarker(
  userId: string,
  markerId: string,
  input: {
    sessionId?: string;
    videoId?: string;
    timeSeconds?: number;
    categoryId?: string;
    comment?: string;
    playerID?: string;
  },
) {
  const prisma = getPrisma();

  const existing = await prisma.analysisMarker.findUnique({ where: { id: markerId } });
  if (!existing || existing.userId !== userId) {
    throw new AppError(404, 'MARKER_NOT_FOUND', 'Marker not found');
  }

  const updated = await prisma.analysisMarker.update({
    where: { id: markerId },
    data: {
      sessionId: input.sessionId,
      videoId: input.videoId,
      timeSeconds: input.timeSeconds,
      categoryId: input.categoryId,
      comment: input.comment,
      playerID: input.playerID,
    },
  });

  return toMarkerDTO(updated);
}

export async function deleteMarker(userId: string, markerId: string) {
  const prisma = getPrisma();

  const existing = await prisma.analysisMarker.findUnique({ where: { id: markerId } });
  if (!existing || existing.userId !== userId) {
    throw new AppError(404, 'MARKER_NOT_FOUND', 'Marker not found');
  }

  await prisma.analysisMarker.delete({ where: { id: markerId } });
}

/* ── Clips ── */

export async function createClip(
  userId: string,
  input: {
    sessionId: string;
    videoId: string;
    name: string;
    startSeconds: number;
    endSeconds: number;
    playerIDs?: unknown;
    note?: string;
  },
) {
  const prisma = getPrisma();

  const clip = await prisma.analysisClip.create({
    data: {
      userId,
      sessionId: input.sessionId,
      videoId: input.videoId,
      name: input.name,
      startSeconds: input.startSeconds,
      endSeconds: input.endSeconds,
      playerIDs: (input.playerIDs ?? []) as string[],
      note: input.note ?? null,
    },
  });

  return toClipDTO(clip);
}

export async function listClips(userId: string) {
  const prisma = getPrisma();

  const clips = await prisma.analysisClip.findMany({
    where: { userId },
    orderBy: { createdAt: 'desc' },
  });

  return clips.map(toClipDTO);
}

export async function updateClip(
  userId: string,
  clipId: string,
  input: {
    sessionId?: string;
    videoId?: string;
    name?: string;
    startSeconds?: number;
    endSeconds?: number;
    playerIDs?: unknown;
    note?: string;
  },
) {
  const prisma = getPrisma();

  const existing = await prisma.analysisClip.findUnique({ where: { id: clipId } });
  if (!existing || existing.userId !== userId) {
    throw new AppError(404, 'CLIP_NOT_FOUND', 'Clip not found');
  }

  const updated = await prisma.analysisClip.update({
    where: { id: clipId },
    data: {
      sessionId: input.sessionId,
      videoId: input.videoId,
      name: input.name,
      startSeconds: input.startSeconds,
      endSeconds: input.endSeconds,
      playerIDs: input.playerIDs as any,
      note: input.note,
    },
  });

  return toClipDTO(updated);
}

export async function deleteClip(userId: string, clipId: string) {
  const prisma = getPrisma();

  const existing = await prisma.analysisClip.findUnique({ where: { id: clipId } });
  if (!existing || existing.userId !== userId) {
    throw new AppError(404, 'CLIP_NOT_FOUND', 'Clip not found');
  }

  await prisma.analysisClip.delete({ where: { id: clipId } });
}

export async function shareClip(
  userId: string,
  clipId: string,
  input: { targetChatID?: string; targetUserIDs?: string[] },
) {
  const prisma = getPrisma();

  const existing = await prisma.analysisClip.findUnique({ where: { id: clipId } });
  if (!existing || existing.userId !== userId) {
    throw new AppError(404, 'CLIP_NOT_FOUND', 'Clip not found');
  }

  return {
    shareURL: '/placeholder',
    sharedAt: new Date().toISOString(),
  };
}

/* ── Drawings ── */

export async function saveDrawings(
  userId: string,
  sessionId: string,
  input: {
    drawings: Array<{
      localId?: string;
      tool: string;
      points: unknown;
      colorHex: string;
      isTemporary?: boolean;
      timeSeconds?: number;
    }>;
  },
) {
  const prisma = getPrisma();

  const session = await prisma.analysisSession.findUnique({ where: { id: sessionId } });
  if (!session || session.userId !== userId) {
    throw new AppError(404, 'SESSION_NOT_FOUND', 'Session not found');
  }

  await prisma.$transaction(async (tx) => {
    // Delete existing drawings for this session
    await tx.analysisDrawing.deleteMany({ where: { sessionId } });

    // Create new drawings
    if (input.drawings.length > 0) {
      await tx.analysisDrawing.createMany({
        data: input.drawings.map((d) => ({
          sessionId,
          userId,
          localId: d.localId ?? null,
          tool: d.tool,
          points: (d.points ?? []) as any,
          colorHex: d.colorHex,
          isTemporary: d.isTemporary ?? false,
          timeSeconds: d.timeSeconds ?? null,
        })),
      });
    }
  });

  return { success: true };
}
