import type { Request, Response } from 'express';
import { AppError } from '../../middleware/errorHandler';
import * as analysisService from './analysis.service';

/* ── Categories ── */

export async function listCategories(req: Request, res: Response) {
  if (!req.auth?.userId) {
    throw new AppError(401, 'UNAUTHORIZED', 'Unauthorized');
  }
  const categories = await analysisService.listAnalysisCategories(req.auth.userId);
  res.status(200).json(categories);
}

export async function createCategory(req: Request, res: Response) {
  if (!req.auth?.userId) {
    throw new AppError(401, 'UNAUTHORIZED', 'Unauthorized');
  }
  const { name, colorHex } = req.body;
  if (!name || !colorHex) {
    throw new AppError(400, 'VALIDATION_ERROR', 'Missing required fields: name, colorHex');
  }
  const category = await analysisService.createAnalysisCategory(req.auth.userId, { name, colorHex });
  res.status(201).json(category);
}

/* ── Videos ── */

export async function registerVideo(req: Request, res: Response) {
  if (!req.auth?.userId) {
    throw new AppError(401, 'UNAUTHORIZED', 'Unauthorized');
  }
  const result = await analysisService.registerVideo(req.auth.userId, req.body);

  // Build absolute upload URL from the request origin
  const origin = `${req.protocol}://${req.get('host')}`;
  const authHeader = req.headers.authorization ?? '';
  const response = {
    ...result,
    uploadURL: result.uploadURL.startsWith('http') ? result.uploadURL : `${origin}${result.uploadURL}`,
    uploadHeaders: authHeader ? { Authorization: authHeader } : {},
  };

  res.status(201).json(response);
}

export async function completeVideoUpload(req: Request, res: Response) {
  if (!req.auth?.userId) {
    throw new AppError(401, 'UNAUTHORIZED', 'Unauthorized');
  }
  const result = await analysisService.completeVideoUpload(
    req.auth.userId,
    req.params.videoId,
    req.body,
  );
  res.status(200).json(result);
}

export async function getPlaybackURL(req: Request, res: Response) {
  if (!req.auth?.userId) {
    throw new AppError(401, 'UNAUTHORIZED', 'Unauthorized');
  }
  const result = await analysisService.getPlaybackURL(req.auth.userId, req.params.videoId);
  res.status(200).json(result);
}

/* ── Sessions ── */

export async function createSession(req: Request, res: Response) {
  if (!req.auth?.userId) {
    throw new AppError(401, 'UNAUTHORIZED', 'Unauthorized');
  }
  const session = await analysisService.createSession(req.auth.userId, req.body);
  res.status(201).json(session);
}

export async function listSessions(req: Request, res: Response) {
  if (!req.auth?.userId) {
    throw new AppError(401, 'UNAUTHORIZED', 'Unauthorized');
  }
  const sessions = await analysisService.listSessions(req.auth.userId);
  res.status(200).json(sessions);
}

export async function getSession(req: Request, res: Response) {
  if (!req.auth?.userId) {
    throw new AppError(401, 'UNAUTHORIZED', 'Unauthorized');
  }
  const result = await analysisService.getSession(req.auth.userId, req.params.sessionId);
  res.status(200).json(result);
}

/* ── Markers ── */

export async function createMarker(req: Request, res: Response) {
  if (!req.auth?.userId) {
    throw new AppError(401, 'UNAUTHORIZED', 'Unauthorized');
  }
  const marker = await analysisService.createMarker(req.auth.userId, req.body);
  res.status(201).json(marker);
}

export async function updateMarker(req: Request, res: Response) {
  if (!req.auth?.userId) {
    throw new AppError(401, 'UNAUTHORIZED', 'Unauthorized');
  }
  const marker = await analysisService.updateMarker(
    req.auth.userId,
    req.params.markerId,
    req.body,
  );
  res.status(200).json(marker);
}

export async function deleteMarker(req: Request, res: Response) {
  if (!req.auth?.userId) {
    throw new AppError(401, 'UNAUTHORIZED', 'Unauthorized');
  }
  await analysisService.deleteMarker(req.auth.userId, req.params.markerId);
  res.status(204).send();
}

/* ── Clips ── */

export async function createClip(req: Request, res: Response) {
  if (!req.auth?.userId) {
    throw new AppError(401, 'UNAUTHORIZED', 'Unauthorized');
  }
  const clip = await analysisService.createClip(req.auth.userId, req.body);
  res.status(201).json(clip);
}

export async function listClips(req: Request, res: Response) {
  if (!req.auth?.userId) {
    throw new AppError(401, 'UNAUTHORIZED', 'Unauthorized');
  }
  const clips = await analysisService.listClips(req.auth.userId);
  res.status(200).json(clips);
}

export async function updateClip(req: Request, res: Response) {
  if (!req.auth?.userId) {
    throw new AppError(401, 'UNAUTHORIZED', 'Unauthorized');
  }
  const clip = await analysisService.updateClip(req.auth.userId, req.params.clipId, req.body);
  res.status(200).json(clip);
}

export async function deleteClip(req: Request, res: Response) {
  if (!req.auth?.userId) {
    throw new AppError(401, 'UNAUTHORIZED', 'Unauthorized');
  }
  await analysisService.deleteClip(req.auth.userId, req.params.clipId);
  res.status(204).send();
}

export async function shareClip(req: Request, res: Response) {
  if (!req.auth?.userId) {
    throw new AppError(401, 'UNAUTHORIZED', 'Unauthorized');
  }
  const result = await analysisService.shareClip(req.auth.userId, req.params.clipId, req.body);
  res.status(200).json(result);
}

/* ── Drawings ── */

export async function saveDrawings(req: Request, res: Response) {
  if (!req.auth?.userId) {
    throw new AppError(401, 'UNAUTHORIZED', 'Unauthorized');
  }
  const result = await analysisService.saveDrawings(
    req.auth.userId,
    req.params.sessionId,
    req.body,
  );
  res.status(200).json(result);
}

/* ── Video upload chunk ── */

export async function uploadVideoChunk(req: Request, res: Response) {
  if (!req.auth?.userId) {
    throw new AppError(401, 'UNAUTHORIZED', 'Unauthorized');
  }

  const videoId = req.params.videoId;
  if (!videoId) {
    throw new AppError(400, 'MISSING_VIDEO_ID', 'videoId parameter is required');
  }

  const partNumber = req.headers['x-part-number']
    ? parseInt(req.headers['x-part-number'] as string, 10)
    : 0;

  // Stub: accept the data and return a synthetic ETag
  const etag = `"part-${partNumber}"`;
  res.setHeader('ETag', etag);
  res.status(200).json({ partNumber, etag });
}
