import type { Request, Response } from 'express';
import { AppError } from '../../middleware/errorHandler';
import * as svc from './cloud.service';

// ─── Helpers ───────────────────────────────────────────

function requireAuth(req: Request): string {
  const userId = req.auth?.userId;
  if (!userId) {
    throw new AppError(401, 'UNAUTHORIZED', 'Unauthorized');
  }
  return userId;
}

function requireQueryTeamId(req: Request): string {
  const teamId = typeof req.query.teamId === 'string' ? req.query.teamId : '';
  if (!teamId) {
    throw new AppError(400, 'MISSING_TEAM_ID', 'teamId query parameter is required');
  }
  return teamId;
}

// ─── Bootstrap ─────────────────────────────────────────

export async function bootstrap(req: Request, res: Response): Promise<void> {
  requireAuth(req);
  const teamId = requireQueryTeamId(req);

  const result = await svc.bootstrap(teamId);
  res.status(200).json(result);
}

// ─── List files ────────────────────────────────────────

export async function listFiles(req: Request, res: Response): Promise<void> {
  requireAuth(req);
  const teamId = requireQueryTeamId(req);

  const params: svc.ListFilesParams = {
    teamId,
    status: typeof req.query.status === 'string' ? req.query.status : undefined,
    cursor: typeof req.query.cursor === 'string' ? req.query.cursor : undefined,
    limit: req.query.limit ? parseInt(req.query.limit as string, 10) : undefined,
    q: typeof req.query.q === 'string' ? req.query.q : undefined,
    type: typeof req.query.type === 'string' ? req.query.type : undefined,
    folderId: typeof req.query.folderId === 'string' ? req.query.folderId : undefined,
    ownerUserId:
      typeof req.query.ownerUserId === 'string' ? req.query.ownerUserId : undefined,
    from: typeof req.query.from === 'string' ? req.query.from : undefined,
    to: typeof req.query.to === 'string' ? req.query.to : undefined,
    minSizeBytes: req.query.minSizeBytes
      ? parseInt(req.query.minSizeBytes as string, 10)
      : undefined,
    maxSizeBytes: req.query.maxSizeBytes
      ? parseInt(req.query.maxSizeBytes as string, 10)
      : undefined,
    sortField:
      typeof req.query.sortField === 'string' ? req.query.sortField : undefined,
    sortDirection:
      req.query.sortDirection === 'asc' || req.query.sortDirection === 'desc'
        ? req.query.sortDirection
        : undefined,
  };

  const result = await svc.listFiles(params);
  res.status(200).json(result);
}

// ─── Largest files ─────────────────────────────────────

export async function largestFiles(req: Request, res: Response): Promise<void> {
  requireAuth(req);
  const teamId = requireQueryTeamId(req);
  const limit = req.query.limit ? parseInt(req.query.limit as string, 10) : 10;

  const files = await svc.getLargestFiles(teamId, limit);
  res.status(200).json(files);
}

// ─── Old files ─────────────────────────────────────────

export async function oldFiles(req: Request, res: Response): Promise<void> {
  requireAuth(req);
  const teamId = requireQueryTeamId(req);
  const olderThanDays = req.query.olderThanDays
    ? parseInt(req.query.olderThanDays as string, 10)
    : 90;
  const limit = req.query.limit ? parseInt(req.query.limit as string, 10) : 10;

  const files = await svc.getOldFiles(teamId, olderThanDays, limit);
  res.status(200).json(files);
}

// ─── Create folder ─────────────────────────────────────

export async function createFolder(req: Request, res: Response): Promise<void> {
  requireAuth(req);

  const { teamID, parentFolderID, name } = req.body;

  if (!teamID || !name) {
    throw new AppError(400, 'MISSING_FIELDS', 'teamID and name are required');
  }

  const folder = await svc.createFolder(teamID, parentFolderID ?? null, name);
  res.status(201).json(folder);
}

// ─── Update folder ─────────────────────────────────────

export async function updateFolder(req: Request, res: Response): Promise<void> {
  requireAuth(req);

  const folderId = req.params.folderId;
  if (!folderId) {
    throw new AppError(400, 'MISSING_FOLDER_ID', 'folderId parameter is required');
  }

  const { name, parentFolderID } = req.body;

  const folder = await svc.updateFolder(folderId, {
    name,
    parentFolderId: parentFolderID,
  });
  res.status(200).json(folder);
}

// ─── Register file ─────────────────────────────────────

export async function registerFile(req: Request, res: Response): Promise<void> {
  const userId = requireAuth(req);

  const {
    teamID,
    folderID,
    name,
    originalName,
    type,
    mimeType,
    sizeBytes,
    moduleHint,
    visibility,
    tags,
    checksum,
    linkedAnalysisSessionID,
    linkedAnalysisClipID,
    linkedTacticsScenarioID,
    linkedTrainingPlanID,
  } = req.body;

  if (!teamID || !name || !originalName || !type || !mimeType) {
    throw new AppError(
      400,
      'MISSING_FIELDS',
      'teamID, name, originalName, type, and mimeType are required',
    );
  }

  const result = await svc.registerFile({
    teamId: teamID,
    ownerUserId: userId,
    name,
    originalName,
    type,
    mimeType,
    sizeBytes,
    folderId: folderID,
    moduleHint,
    visibility,
    tags,
    checksum,
    linkedAnalysisSessionID,
    linkedAnalysisClipID,
    linkedTacticsScenarioID,
    linkedTrainingPlanID,
  });

  // Build absolute upload URL from the request origin
  const origin = `${req.protocol}://${req.get('host')}`;
  const response = {
    ...result,
    uploadURL: result.uploadURL.startsWith('http') ? result.uploadURL : `${origin}${result.uploadURL}`,
  };

  res.status(201).json(response);
}

// ─── Upload chunk ─────────────────────────────────────

export async function uploadChunk(req: Request, res: Response): Promise<void> {
  requireAuth(req);

  const fileId = req.params.fileId;
  if (!fileId) {
    throw new AppError(400, 'MISSING_FILE_ID', 'fileId parameter is required');
  }

  const partNumber = req.headers['x-part-number']
    ? parseInt(req.headers['x-part-number'] as string, 10)
    : 0;

  // In a production system this would stream the chunk to object storage.
  // For now we accept the data and return a synthetic ETag so the iOS
  // upload flow can proceed end-to-end.
  const etag = `"part-${partNumber}"`;

  res.setHeader('ETag', etag);
  res.status(200).json({ partNumber, etag });
}

// ─── Complete upload ───────────────────────────────────

export async function completeUpload(req: Request, res: Response): Promise<void> {
  requireAuth(req);

  const fileId = req.params.fileId;
  if (!fileId) {
    throw new AppError(400, 'MISSING_FILE_ID', 'fileId parameter is required');
  }

  const { etags } = req.body;

  const file = await svc.completeUpload(fileId, { etags });
  res.status(200).json(file);
}

// ─── Update file metadata ──────────────────────────────

export async function updateFile(req: Request, res: Response): Promise<void> {
  requireAuth(req);

  const fileId = req.params.fileId;
  if (!fileId) {
    throw new AppError(400, 'MISSING_FILE_ID', 'fileId parameter is required');
  }

  const file = await svc.updateFile(fileId, req.body);
  res.status(200).json(file);
}

// ─── Move file ─────────────────────────────────────────

export async function moveFile(req: Request, res: Response): Promise<void> {
  requireAuth(req);

  const fileId = req.params.fileId;
  if (!fileId) {
    throw new AppError(400, 'MISSING_FILE_ID', 'fileId parameter is required');
  }

  const { folderID } = req.body;

  const file = await svc.moveFile(fileId, folderID ?? null);
  res.status(200).json(file);
}

// ─── Trash file ────────────────────────────────────────

export async function trashFile(req: Request, res: Response): Promise<void> {
  requireAuth(req);

  const fileId = req.params.fileId;
  if (!fileId) {
    throw new AppError(400, 'MISSING_FILE_ID', 'fileId parameter is required');
  }

  const deletedAt = req.body.deletedAt ?? new Date().toISOString();
  const file = await svc.trashFile(fileId, deletedAt);
  res.status(200).json(file);
}

// ─── Restore file ──────────────────────────────────────

export async function restoreFile(req: Request, res: Response): Promise<void> {
  requireAuth(req);

  const fileId = req.params.fileId;
  if (!fileId) {
    throw new AppError(400, 'MISSING_FILE_ID', 'fileId parameter is required');
  }

  const { folderID } = req.body;
  const file = await svc.restoreFile(fileId, folderID);
  res.status(200).json(file);
}

// ─── Permanent delete ──────────────────────────────────

export async function deleteFile(req: Request, res: Response): Promise<void> {
  requireAuth(req);

  const fileId = req.params.fileId;
  if (!fileId) {
    throw new AppError(400, 'MISSING_FILE_ID', 'fileId parameter is required');
  }

  await svc.permanentDeleteFile(fileId);
  res.status(204).send();
}
