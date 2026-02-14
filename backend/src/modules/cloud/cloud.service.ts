import { getPrisma } from '../../lib/prisma';
import { AppError } from '../../middleware/errorHandler';

// ─── DTOs ──────────────────────────────────────────────

export interface CloudFolderDTO {
  id: string;
  teamID: string;
  parentID: string | null;
  name: string;
  isSystemFolder: boolean;
  isDeleted: boolean;
  createdAt: string;
  updatedAt: string;
}

export interface CloudFileDTO {
  id: string;
  teamID: string;
  ownerUserID: string;
  name: string;
  originalName: string;
  type: string;
  mimeType: string;
  sizeBytes: number;
  folderID: string | null;
  tags: string[];
  moduleHint: string | null;
  visibility: string;
  sharedUserIDs: string[];
  checksum: string | null;
  uploadStatus: string;
  deletedAt: string | null;
  linkedAnalysisSessionID: string | null;
  linkedAnalysisClipID: string | null;
  linkedTacticsScenarioID: string | null;
  linkedTrainingPlanID: string | null;
  createdAt: string;
  updatedAt: string;
}

export interface UsageDTO {
  teamID: string;
  quotaBytes: number;
  usedBytes: number;
  updatedAt: string;
}

// ─── Helpers ───────────────────────────────────────────

const QUOTA_BYTES = 5_368_709_120; // 5 GB

const SYSTEM_FOLDER_NAMES = [
  'Videos',
  'Clips',
  'Taktik',
  'Trainings',
  'Bilder',
  'Dokumente',
  'Exporte',
];

function toFolderDTO(f: {
  id: string;
  teamId: string;
  parentId: string | null;
  name: string;
  isSystemFolder: boolean;
  isDeleted: boolean;
  createdAt: Date;
  updatedAt: Date;
}): CloudFolderDTO {
  return {
    id: f.id,
    teamID: f.teamId,
    parentID: f.parentId,
    name: f.name,
    isSystemFolder: f.isSystemFolder,
    isDeleted: f.isDeleted,
    createdAt: f.createdAt.toISOString(),
    updatedAt: f.updatedAt.toISOString(),
  };
}

function toFileDTO(f: {
  id: string;
  teamId: string;
  ownerUserId: string;
  name: string;
  originalName: string;
  type: string;
  mimeType: string;
  sizeBytes: number;
  folderId: string | null;
  tags: string[];
  moduleHint: string | null;
  visibility: string;
  sharedUserIds: string[];
  checksum: string | null;
  uploadStatus: string;
  deletedAt: Date | null;
  linkedAnalysisSessionID: string | null;
  linkedAnalysisClipID: string | null;
  linkedTacticsScenarioID: string | null;
  linkedTrainingPlanID: string | null;
  createdAt: Date;
  updatedAt: Date;
}): CloudFileDTO {
  return {
    id: f.id,
    teamID: f.teamId,
    ownerUserID: f.ownerUserId,
    name: f.name,
    originalName: f.originalName,
    type: f.type,
    mimeType: f.mimeType,
    sizeBytes: f.sizeBytes,
    folderID: f.folderId,
    tags: f.tags,
    moduleHint: f.moduleHint,
    visibility: f.visibility,
    sharedUserIDs: f.sharedUserIds,
    checksum: f.checksum,
    uploadStatus: f.uploadStatus,
    deletedAt: f.deletedAt ? f.deletedAt.toISOString() : null,
    linkedAnalysisSessionID: f.linkedAnalysisSessionID,
    linkedAnalysisClipID: f.linkedAnalysisClipID,
    linkedTacticsScenarioID: f.linkedTacticsScenarioID,
    linkedTrainingPlanID: f.linkedTrainingPlanID,
    createdAt: f.createdAt.toISOString(),
    updatedAt: f.updatedAt.toISOString(),
  };
}

// ─── Folder seed ───────────────────────────────────────

async function ensureSystemFolders(teamId: string): Promise<void> {
  const prisma = getPrisma();

  const existing = await prisma.cloudFolder.findFirst({
    where: { teamId, isSystemFolder: true },
  });

  if (existing) return;

  // Create Root first
  const root = await prisma.cloudFolder.create({
    data: {
      teamId,
      name: 'Root',
      parentId: null,
      isSystemFolder: true,
    },
  });

  // Create system children under Root
  for (const name of SYSTEM_FOLDER_NAMES) {
    await prisma.cloudFolder.create({
      data: {
        teamId,
        name,
        parentId: root.id,
        isSystemFolder: true,
      },
    });
  }
}

// ─── Usage ─────────────────────────────────────────────

export async function getUsage(teamId: string): Promise<UsageDTO> {
  const prisma = getPrisma();

  const result = await prisma.cloudFile.aggregate({
    where: { teamId, deletedAt: null },
    _sum: { sizeBytes: true },
  });

  return {
    teamID: teamId,
    quotaBytes: QUOTA_BYTES,
    usedBytes: result._sum.sizeBytes ?? 0,
    updatedAt: new Date().toISOString(),
  };
}

// ─── Bootstrap ─────────────────────────────────────────

export async function bootstrap(teamId: string): Promise<{
  teamID: string;
  usage: UsageDTO;
  folders: CloudFolderDTO[];
  files: CloudFileDTO[];
  nextCursor: string | null;
}> {
  await ensureSystemFolders(teamId);

  const prisma = getPrisma();

  // Clean up files stuck in "uploading" for more than 1 hour
  const staleThreshold = new Date(Date.now() - 60 * 60 * 1000);
  await prisma.cloudFile.deleteMany({
    where: {
      teamId,
      uploadStatus: 'uploading',
      createdAt: { lt: staleThreshold },
    },
  });

  const [usage, folders, files] = await Promise.all([
    getUsage(teamId),
    prisma.cloudFolder.findMany({
      where: { teamId, isDeleted: false },
      orderBy: { createdAt: 'asc' },
    }),
    prisma.cloudFile.findMany({
      where: { teamId, deletedAt: null },
      orderBy: { createdAt: 'desc' },
      take: 50,
    }),
  ]);

  return {
    teamID: teamId,
    usage,
    folders: folders.map(toFolderDTO),
    files: files.map(toFileDTO),
    nextCursor: null,
  };
}

// ─── List files ────────────────────────────────────────

export interface ListFilesParams {
  teamId: string;
  status?: string;
  cursor?: string;
  limit?: number;
  q?: string;
  type?: string;
  folderId?: string;
  ownerUserId?: string;
  from?: string;
  to?: string;
  minSizeBytes?: number;
  maxSizeBytes?: number;
  sortField?: string;
  sortDirection?: 'asc' | 'desc';
}

export async function listFiles(params: ListFilesParams): Promise<{
  items: CloudFileDTO[];
  nextCursor: string | null;
}> {
  const prisma = getPrisma();
  const limit = params.limit ?? 50;

  // Build where clause
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const where: any = { teamId: params.teamId, deletedAt: null };

  if (params.status) {
    where.uploadStatus = params.status;
  }

  if (params.q) {
    where.name = { contains: params.q, mode: 'insensitive' };
  }

  if (params.type) {
    where.type = params.type;
  }

  if (params.folderId) {
    where.folderId = params.folderId;
  }

  if (params.ownerUserId) {
    where.ownerUserId = params.ownerUserId;
  }

  if (params.from || params.to) {
    where.createdAt = {};
    if (params.from) where.createdAt.gte = new Date(params.from);
    if (params.to) where.createdAt.lte = new Date(params.to);
  }

  if (params.minSizeBytes !== undefined || params.maxSizeBytes !== undefined) {
    where.sizeBytes = {};
    if (params.minSizeBytes !== undefined) where.sizeBytes.gte = params.minSizeBytes;
    if (params.maxSizeBytes !== undefined) where.sizeBytes.lte = params.maxSizeBytes;
  }

  // Build orderBy
  const sortField = params.sortField ?? 'createdAt';
  const sortDirection = params.sortDirection ?? 'desc';
  const orderBy = { [sortField]: sortDirection };

  // Cursor-based pagination
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const findArgs: any = {
    where,
    orderBy,
    take: limit + 1,
  };

  if (params.cursor) {
    findArgs.cursor = { id: params.cursor };
    findArgs.skip = 1; // skip the cursor itself
  }

  const files = await prisma.cloudFile.findMany(findArgs);

  let nextCursor: string | null = null;
  if (files.length > limit) {
    files.pop();
    nextCursor = files[files.length - 1].id;
  }

  return {
    items: files.map(toFileDTO),
    nextCursor,
  };
}

// ─── Largest files ─────────────────────────────────────

export async function getLargestFiles(
  teamId: string,
  limit: number = 10,
): Promise<CloudFileDTO[]> {
  const prisma = getPrisma();

  const files = await prisma.cloudFile.findMany({
    where: { teamId, deletedAt: null },
    orderBy: { sizeBytes: 'desc' },
    take: limit,
  });

  return files.map(toFileDTO);
}

// ─── Old files ─────────────────────────────────────────

export async function getOldFiles(
  teamId: string,
  olderThanDays: number = 90,
  limit: number = 10,
): Promise<CloudFileDTO[]> {
  const prisma = getPrisma();

  const cutoff = new Date();
  cutoff.setDate(cutoff.getDate() - olderThanDays);

  const files = await prisma.cloudFile.findMany({
    where: {
      teamId,
      deletedAt: null,
      updatedAt: { lte: cutoff },
    },
    orderBy: { updatedAt: 'asc' },
    take: limit,
  });

  return files.map(toFileDTO);
}

// ─── Folders ───────────────────────────────────────────

export async function createFolder(
  teamId: string,
  parentFolderId: string | null,
  name: string,
): Promise<CloudFolderDTO> {
  const prisma = getPrisma();

  if (parentFolderId) {
    const parent = await prisma.cloudFolder.findUnique({
      where: { id: parentFolderId },
    });
    if (!parent || parent.teamId !== teamId) {
      throw new AppError(404, 'PARENT_FOLDER_NOT_FOUND', 'Parent folder not found');
    }
  }

  const folder = await prisma.cloudFolder.create({
    data: {
      teamId,
      parentId: parentFolderId,
      name,
      isSystemFolder: false,
    },
  });

  return toFolderDTO(folder);
}

export async function updateFolder(
  folderId: string,
  data: { name?: string; parentFolderId?: string | null },
): Promise<CloudFolderDTO> {
  const prisma = getPrisma();

  const folder = await prisma.cloudFolder.findUnique({
    where: { id: folderId },
  });

  if (!folder) {
    throw new AppError(404, 'FOLDER_NOT_FOUND', 'Folder not found');
  }

  if (folder.isSystemFolder && data.name) {
    throw new AppError(400, 'CANNOT_RENAME_SYSTEM_FOLDER', 'Cannot rename a system folder');
  }

  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const updateData: any = {};
  if (data.name !== undefined) updateData.name = data.name;
  if (data.parentFolderId !== undefined) updateData.parentId = data.parentFolderId;

  const updated = await prisma.cloudFolder.update({
    where: { id: folderId },
    data: updateData,
  });

  return toFolderDTO(updated);
}

// ─── File registration (upload init) ───────────────────

export interface RegisterFileInput {
  teamId: string;
  ownerUserId: string;
  name: string;
  originalName: string;
  type: string;
  mimeType: string;
  sizeBytes?: number;
  folderId?: string;
  moduleHint?: string;
  visibility?: string;
  tags?: string[];
  checksum?: string;
  linkedAnalysisSessionID?: string;
  linkedAnalysisClipID?: string;
  linkedTacticsScenarioID?: string;
  linkedTrainingPlanID?: string;
}

export async function registerFile(input: RegisterFileInput): Promise<{
  fileID: string;
  uploadID: string;
  uploadURL: string;
  uploadHeaders: Record<string, string>;
  chunkSizeBytes: number;
  totalParts: number;
  expiresAt: string | null;
}> {
  const prisma = getPrisma();

  // Verify folder exists if provided
  if (input.folderId) {
    const folder = await prisma.cloudFolder.findUnique({
      where: { id: input.folderId },
    });
    if (!folder || folder.teamId !== input.teamId) {
      throw new AppError(404, 'FOLDER_NOT_FOUND', 'Target folder not found');
    }
  }

  const file = await prisma.cloudFile.create({
    data: {
      teamId: input.teamId,
      ownerUserId: input.ownerUserId,
      name: input.name,
      originalName: input.originalName,
      type: input.type,
      mimeType: input.mimeType,
      sizeBytes: input.sizeBytes ?? 0,
      folderId: input.folderId ?? null,
      uploadStatus: 'uploading',
      moduleHint: input.moduleHint ?? null,
      visibility: input.visibility ?? 'team_wide',
      tags: input.tags ?? [],
      checksum: input.checksum ?? null,
      linkedAnalysisSessionID: input.linkedAnalysisSessionID ?? null,
      linkedAnalysisClipID: input.linkedAnalysisClipID ?? null,
      linkedTacticsScenarioID: input.linkedTacticsScenarioID ?? null,
      linkedTrainingPlanID: input.linkedTrainingPlanID ?? null,
    },
  });

  const DEFAULT_CHUNK_SIZE = 5 * 1024 * 1024; // 5 MB
  const totalParts = Math.max(1, Math.ceil((input.sizeBytes ?? 0) / DEFAULT_CHUNK_SIZE));

  return {
    fileID: file.id,
    uploadID: file.id,
    uploadURL: `/api/v1/cloud/files/${file.id}/upload`,
    uploadHeaders: {},
    chunkSizeBytes: DEFAULT_CHUNK_SIZE,
    totalParts,
    expiresAt: null,
  };
}

// ─── Complete upload ───────────────────────────────────

export async function completeUpload(
  fileId: string,
  input: { etags?: string[] },
): Promise<CloudFileDTO> {
  const prisma = getPrisma();

  const file = await prisma.cloudFile.findUnique({
    where: { id: fileId },
  });

  if (!file) {
    throw new AppError(404, 'FILE_NOT_FOUND', 'File not found');
  }

  if (file.uploadStatus !== 'uploading') {
    throw new AppError(400, 'INVALID_UPLOAD_STATUS', 'File is not in uploading state');
  }

  const updated = await prisma.cloudFile.update({
    where: { id: fileId },
    data: {
      uploadStatus: 'ready',
    },
  });

  return toFileDTO(updated);
}

// ─── Update file metadata ──────────────────────────────

export interface UpdateFileInput {
  name?: string;
  tags?: string[];
  visibility?: string;
  sharedUserIDs?: string[];
  moduleHint?: string;
  linkedAnalysisSessionID?: string | null;
  linkedAnalysisClipID?: string | null;
  linkedTacticsScenarioID?: string | null;
  linkedTrainingPlanID?: string | null;
}

export async function updateFile(
  fileId: string,
  input: UpdateFileInput,
): Promise<CloudFileDTO> {
  const prisma = getPrisma();

  const file = await prisma.cloudFile.findUnique({
    where: { id: fileId },
  });

  if (!file) {
    throw new AppError(404, 'FILE_NOT_FOUND', 'File not found');
  }

  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const updateData: any = {};
  if (input.name !== undefined) updateData.name = input.name;
  if (input.tags !== undefined) updateData.tags = input.tags;
  if (input.visibility !== undefined) updateData.visibility = input.visibility;
  if (input.sharedUserIDs !== undefined) updateData.sharedUserIds = input.sharedUserIDs;
  if (input.moduleHint !== undefined) updateData.moduleHint = input.moduleHint;
  if (input.linkedAnalysisSessionID !== undefined)
    updateData.linkedAnalysisSessionID = input.linkedAnalysisSessionID;
  if (input.linkedAnalysisClipID !== undefined)
    updateData.linkedAnalysisClipID = input.linkedAnalysisClipID;
  if (input.linkedTacticsScenarioID !== undefined)
    updateData.linkedTacticsScenarioID = input.linkedTacticsScenarioID;
  if (input.linkedTrainingPlanID !== undefined)
    updateData.linkedTrainingPlanID = input.linkedTrainingPlanID;

  const updated = await prisma.cloudFile.update({
    where: { id: fileId },
    data: updateData,
  });

  return toFileDTO(updated);
}

// ─── Move file ─────────────────────────────────────────

export async function moveFile(
  fileId: string,
  folderId: string | null,
): Promise<CloudFileDTO> {
  const prisma = getPrisma();

  const file = await prisma.cloudFile.findUnique({
    where: { id: fileId },
  });

  if (!file) {
    throw new AppError(404, 'FILE_NOT_FOUND', 'File not found');
  }

  if (folderId) {
    const folder = await prisma.cloudFolder.findUnique({
      where: { id: folderId },
    });
    if (!folder || folder.teamId !== file.teamId) {
      throw new AppError(404, 'FOLDER_NOT_FOUND', 'Target folder not found');
    }
  }

  const updated = await prisma.cloudFile.update({
    where: { id: fileId },
    data: { folderId },
  });

  return toFileDTO(updated);
}

// ─── Trash / Restore / Delete ──────────────────────────

export async function trashFile(
  fileId: string,
  deletedAt: string,
): Promise<CloudFileDTO> {
  const prisma = getPrisma();

  const file = await prisma.cloudFile.findUnique({
    where: { id: fileId },
  });

  if (!file) {
    throw new AppError(404, 'FILE_NOT_FOUND', 'File not found');
  }

  const updated = await prisma.cloudFile.update({
    where: { id: fileId },
    data: { deletedAt: new Date(deletedAt) },
  });

  return toFileDTO(updated);
}

export async function restoreFile(
  fileId: string,
  folderId?: string | null,
): Promise<CloudFileDTO> {
  const prisma = getPrisma();

  const file = await prisma.cloudFile.findUnique({
    where: { id: fileId },
  });

  if (!file) {
    throw new AppError(404, 'FILE_NOT_FOUND', 'File not found');
  }

  if (!file.deletedAt) {
    throw new AppError(400, 'FILE_NOT_TRASHED', 'File is not in trash');
  }

  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const updateData: any = { deletedAt: null };
  if (folderId !== undefined) {
    updateData.folderId = folderId;
  }

  const updated = await prisma.cloudFile.update({
    where: { id: fileId },
    data: updateData,
  });

  return toFileDTO(updated);
}

export async function permanentDeleteFile(fileId: string): Promise<void> {
  const prisma = getPrisma();

  const file = await prisma.cloudFile.findUnique({
    where: { id: fileId },
  });

  if (!file) {
    throw new AppError(404, 'FILE_NOT_FOUND', 'File not found');
  }

  await prisma.cloudFile.delete({
    where: { id: fileId },
  });
}
