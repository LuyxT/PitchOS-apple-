import path from 'path';
import fs from 'fs';
import { getPrisma } from '../../lib/prisma';
import { AppError } from '../../middleware/errorHandler';

/* ── Upload directory ── */

const UPLOAD_DIR = path.join(process.cwd(), 'uploads', 'videos');

export function getVideoUploadDir() {
  if (!fs.existsSync(UPLOAD_DIR)) {
    fs.mkdirSync(UPLOAD_DIR, { recursive: true });
  }
  return UPLOAD_DIR;
}

export function getVideoFilePath(videoId: string) {
  return path.join(getVideoUploadDir(), `${videoId}.data`);
}

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
    videoID: s.videoId,
    title: s.title,
    matchID: s.matchId,
    teamID: s.teamId,
    userID: s.userId,
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
    sessionID: m.sessionId,
    videoID: m.videoId,
    timeSeconds: m.timeSeconds,
    categoryID: m.categoryId,
    comment: m.comment,
    playerID: m.playerID,
    userID: m.userId,
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
    sessionID: c.sessionId,
    videoID: c.videoId,
    name: c.name,
    startSeconds: c.startSeconds,
    endSeconds: c.endSeconds,
    playerIDs: c.playerIDs,
    note: c.note,
    userID: c.userId,
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
    sessionID: d.sessionId,
    localID: d.localId,
    tool: d.tool,
    points: d.points,
    colorHex: d.colorHex,
    isTemporary: d.isTemporary,
    timeSeconds: d.timeSeconds,
    userID: d.userId,
    createdAt: d.createdAt.toISOString(),
    updatedAt: d.updatedAt.toISOString(),
  };
}

/* ── Categories ── */

const DEFAULT_ANALYSIS_CATEGORIES = [
  { name: 'Tor', colorHex: '#10B981', isSystem: true },
  { name: 'Pressing', colorHex: '#3B82F6', isSystem: true },
  { name: 'Aufbau', colorHex: '#F59E0B', isSystem: true },
];

async function ensureDefaultAnalysisCategories(userId: string) {
  const prisma = getPrisma();
  const count = await prisma.analysisCategory.count({ where: { userId } });
  if (count > 0) return;
  await prisma.analysisCategory.createMany({
    data: DEFAULT_ANALYSIS_CATEGORIES.map((cat) => ({ ...cat, userId })),
  });
}

export async function listAnalysisCategories(userId: string) {
  const prisma = getPrisma();
  await ensureDefaultAnalysisCategories(userId);
  const categories = await prisma.analysisCategory.findMany({
    where: { userId },
    orderBy: { createdAt: 'asc' },
  });
  return categories.map((c) => ({
    id: c.id,
    name: c.name,
    colorHex: c.colorHex,
    isSystem: c.isSystem,
  }));
}

export async function createAnalysisCategory(userId: string, input: { name: string; colorHex: string }) {
  const prisma = getPrisma();
  const category = await prisma.analysisCategory.create({
    data: { name: input.name, colorHex: input.colorHex, isSystem: false, userId },
  });
  return { id: category.id, name: category.name, colorHex: category.colorHex, isSystem: category.isSystem };
}

/* ── Videos ── */

export async function registerVideo(
  userId: string,
  input: { filename: string; fileSize: number; mimeType: string; sha256?: string; importedAt?: string },
) {
  const prisma = getPrisma();

  const video = await prisma.analysisVideo.create({
    data: {
      userId,
      filename: input.filename,
      fileSize: input.fileSize,
      mimeType: input.mimeType,
      sha256: input.sha256 ?? null,
      importedAt: input.importedAt ? new Date(input.importedAt) : null,
    },
  });

  return {
    videoID: video.id,
    uploadURL: `/api/v1/analysis/videos/${video.id}/upload`,
    uploadHeaders: {} as Record<string, string>,
    expiresAt: null as string | null,
  };
}

export async function completeVideoUpload(
  userId: string,
  videoId: string,
  input: { fileSize?: number; sha256?: string; completedAt?: string; playbackURL?: string },
) {
  const prisma = getPrisma();

  const video = await prisma.analysisVideo.findUnique({ where: { id: videoId } });
  if (!video || video.userId !== userId) {
    throw new AppError(404, 'VIDEO_NOT_FOUND', 'Video not found');
  }

  const updated = await prisma.analysisVideo.update({
    where: { id: videoId },
    data: {
      importedAt: input.completedAt ? new Date(input.completedAt) : new Date(),
      playbackURL: input.playbackURL ?? video.playbackURL,
      fileSize: input.fileSize ?? video.fileSize,
      sha256: input.sha256 ?? video.sha256,
    },
  });

  return {
    videoID: updated.id,
    playbackReady: true,
  };
}

export async function getPlaybackURL(userId: string, videoId: string, origin: string) {
  const prisma = getPrisma();

  const video = await prisma.analysisVideo.findUnique({ where: { id: videoId } });
  if (!video || video.userId !== userId) {
    throw new AppError(404, 'VIDEO_NOT_FOUND', 'Video not found');
  }

  const expiresAt = new Date(Date.now() + 60 * 60 * 1000); // 1 hour from now

  // Check if the video file exists on disk
  const filePath = getVideoFilePath(videoId);
  const fileExists = fs.existsSync(filePath);

  const streamURL = fileExists
    ? `${origin}/api/v1/analysis/videos/${videoId}/stream`
    : video.playbackURL ?? `${origin}/api/v1/analysis/videos/${videoId}/stream`;

  return {
    signedPlaybackURL: streamURL,
    expiresAt: expiresAt.toISOString(),
  };
}

/* ── Sessions ── */

export async function createSession(
  userId: string,
  input: { videoID?: string; videoId?: string; title: string; matchID?: string; matchId?: string; teamID?: string; teamId?: string },
) {
  const prisma = getPrisma();

  const session = await prisma.analysisSession.create({
    data: {
      userId,
      videoId: input.videoID ?? input.videoId ?? '',
      title: input.title,
      matchId: input.matchID ?? input.matchId ?? null,
      teamId: input.teamID ?? input.teamId ?? null,
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
    sessionID?: string;
    sessionId?: string;
    videoID?: string;
    videoId?: string;
    timeSeconds: number;
    categoryID?: string;
    categoryId?: string;
    comment?: string;
    playerID?: string;
  },
) {
  const prisma = getPrisma();

  const marker = await prisma.analysisMarker.create({
    data: {
      userId,
      sessionId: input.sessionID ?? input.sessionId ?? '',
      videoId: input.videoID ?? input.videoId ?? '',
      timeSeconds: input.timeSeconds,
      categoryId: input.categoryID ?? input.categoryId ?? null,
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
    sessionID?: string;
    sessionId?: string;
    videoID?: string;
    videoId?: string;
    timeSeconds?: number;
    categoryID?: string;
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
      sessionId: input.sessionID ?? input.sessionId,
      videoId: input.videoID ?? input.videoId,
      timeSeconds: input.timeSeconds,
      categoryId: input.categoryID ?? input.categoryId,
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
    sessionID?: string;
    sessionId?: string;
    videoID?: string;
    videoId?: string;
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
      sessionId: input.sessionID ?? input.sessionId ?? '',
      videoId: input.videoID ?? input.videoId ?? '',
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
    sessionID?: string;
    sessionId?: string;
    videoID?: string;
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
      sessionId: input.sessionID ?? input.sessionId,
      videoId: input.videoID ?? input.videoId,
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
  input: { playerIDs?: string[]; threadID?: string; message?: string; targetChatID?: string; targetUserIDs?: string[] },
) {
  const prisma = getPrisma();

  const existing = await prisma.analysisClip.findUnique({ where: { id: clipId } });
  if (!existing || existing.userId !== userId) {
    throw new AppError(404, 'CLIP_NOT_FOUND', 'Clip not found');
  }

  return {
    threadID: input.threadID ?? null,
    messageIDs: [] as string[],
  };
}

/* ── Drawings ── */

export async function saveDrawings(
  userId: string,
  sessionId: string,
  input: {
    drawings: Array<{
      localID?: string;
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
          localId: d.localID ?? d.localId ?? null,
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
