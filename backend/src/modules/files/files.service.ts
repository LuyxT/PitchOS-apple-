import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { FileUploadStatus, FileVisibility } from '@prisma/client';
import { randomUUID } from 'crypto';
import { ConfigService } from '@nestjs/config';
import { PrismaService } from '../../prisma/prisma.service';
import { JwtPayload } from '../auth/dto/jwt-payload.dto';
import {
  CompleteUploadDto,
  CreateFolderDto,
  RegisterUploadDto,
} from './dto/files.dto';
import { S3StorageService } from './s3-storage.service';

const DEFAULT_FOLDERS = [
  '/Videos',
  '/Clips',
  '/Analysen',
  '/Taktiken',
  '/Trainings',
  '/Bilder',
  '/Dokumente',
  '/Exporte',
  '/Papierkorb',
];

@Injectable()
export class FilesService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly storageService: S3StorageService,
    private readonly configService: ConfigService,
  ) {}

  async bootstrap(currentUser: JwtPayload) {
    await this.ensureTeamQuota(currentUser.orgId);
    await this.ensureDefaultFolderStructure(currentUser.orgId);
    return this.getUsage(currentUser.orgId);
  }

  async getUsage(organizationId: string) {
    const quota = await this.ensureTeamQuota(organizationId);
    const used = Number(quota.usedBytes);
    const max = Number(quota.quotaBytes);
    const percent = max > 0 ? Math.min(100, Math.round((used / max) * 100)) : 0;
    return {
      quotaBytes: max,
      usedBytes: used,
      percent,
      warning: percent >= 80,
      critical: percent >= 95,
    };
  }

  async listFolders(currentUser: JwtPayload) {
    await this.ensureDefaultFolderStructure(currentUser.orgId);
    return this.prisma.cloudFolder.findMany({
      where: { organizationId: currentUser.orgId },
      orderBy: { path: 'asc' },
    });
  }

  async createFolder(currentUser: JwtPayload, input: CreateFolderDto) {
    if (!this.canManageFiles(currentUser)) {
      throw new ForbiddenException('No permission to create folders');
    }

    const normalizedPath = this.normalizePath(input.path, input.name);
    const existing = await this.prisma.cloudFolder.findFirst({
      where: { organizationId: currentUser.orgId, path: normalizedPath },
    });
    if (existing) {
      throw new BadRequestException('Folder already exists');
    }

    return this.prisma.cloudFolder.create({
      data: {
        organizationId: currentUser.orgId,
        name: input.name,
        path: normalizedPath,
        parentId: await this.findParentFolderId(currentUser.orgId, input.path),
        createdBy: currentUser.sub,
      },
    });
  }

  async listFiles(
    currentUser: JwtPayload,
    query?: string,
    type?: string,
    folderPath?: string,
    includeTrash = false,
    limit = 50,
    cursor?: string,
  ) {
    const folder = folderPath
      ? await this.prisma.cloudFolder.findFirst({
          where: { organizationId: currentUser.orgId, path: folderPath },
        })
      : null;

    const files = await this.prisma.cloudFile.findMany({
      where: {
        organizationId: currentUser.orgId,
        deletedAt: includeTrash ? { not: null } : null,
        folderId: folder?.id,
        type: type ? (type as any) : undefined,
        name: query ? { contains: query, mode: 'insensitive' } : undefined,
        OR: this.canManageFiles(currentUser)
          ? undefined
          : [
              { ownerUserId: currentUser.sub },
              { explicitShareIds: { has: currentUser.sub } },
            ],
      },
      take: Math.min(Math.max(limit, 1), 100),
      skip: cursor ? 1 : 0,
      cursor: cursor ? { id: cursor } : undefined,
      orderBy: { updatedAt: 'desc' },
    });

    return {
      data: files,
      nextCursor: files.length === limit ? files[files.length - 1].id : null,
    };
  }

  async registerUpload(currentUser: JwtPayload, input: RegisterUploadDto) {
    await this.ensureDefaultFolderStructure(currentUser.orgId);
    const quota = await this.ensureTeamQuota(currentUser.orgId);

    const nextUsedBytes = Number(quota.usedBytes) + input.sizeBytes;
    if (nextUsedBytes > Number(quota.quotaBytes)) {
      throw new BadRequestException('Speicher voll');
    }

    const folder = await this.prisma.cloudFolder.findFirst({
      where: { organizationId: currentUser.orgId, path: input.folderPath },
    });

    if (!folder) {
      throw new NotFoundException('Ordner nicht gefunden');
    }

    const extension = this.fileExtension(input.originalName);
    const storageKey = `${currentUser.orgId}/${input.teamId}/${randomUUID()}${extension}`;

    const file = await this.prisma.cloudFile.create({
      data: {
        organizationId: currentUser.orgId,
        teamId: input.teamId,
        ownerUserId: currentUser.sub,
        folderId: folder.id,
        name: input.name,
        originalName: input.originalName,
        type: input.type,
        mimeType: input.mimeType,
        sizeBytes: BigInt(input.sizeBytes),
        storageKey,
        moduleHint: input.moduleHint,
        tags: input.tags ?? [],
        visibility: input.visibility ?? FileVisibility.TEAM,
        explicitShareIds: [],
        uploadStatus: FileUploadStatus.REGISTERED,
      },
    });

    const uploadUrl = await this.storageService.createUploadUrl(storageKey, input.mimeType);

    return {
      fileId: file.id,
      uploadUrl,
      uploadHeaders: {
        'Content-Type': input.mimeType,
      },
      expiresAt: new Date(Date.now() + 15 * 60 * 1000).toISOString(),
    };
  }

  async completeUpload(currentUser: JwtPayload, fileId: string, input: CompleteUploadDto) {
    const file = await this.prisma.cloudFile.findFirst({
      where: {
        id: fileId,
        organizationId: currentUser.orgId,
      },
    });

    if (!file) {
      throw new NotFoundException('Datei nicht gefunden');
    }

    if (!input.success) {
      await this.prisma.cloudFile.update({
        where: { id: file.id },
        data: { uploadStatus: FileUploadStatus.FAILED },
      });
      throw new BadRequestException('Upload fehlgeschlagen');
    }

    await this.prisma.$transaction(async (tx) => {
      await tx.cloudFile.update({
        where: { id: file.id },
        data: {
          uploadStatus: FileUploadStatus.READY,
          checksum: input.checksum,
        },
      });

      await tx.teamQuota.update({
        where: { organizationId: currentUser.orgId },
        data: {
          usedBytes: { increment: file.sizeBytes },
        },
      });
    });

    return { success: true };
  }

  async downloadUrl(currentUser: JwtPayload, fileId: string) {
    const file = await this.ensureFileAccess(currentUser, fileId);
    if (file.uploadStatus !== FileUploadStatus.READY) {
      throw new BadRequestException('Datei nicht bereit');
    }

    const url = await this.storageService.createDownloadUrl(file.storageKey);
    return { url, expiresIn: 300 };
  }

  async moveToTrash(currentUser: JwtPayload, fileId: string) {
    const file = await this.ensureOwnedOrManager(currentUser, fileId);
    const trash = await this.prisma.cloudFolder.findFirst({
      where: { organizationId: currentUser.orgId, path: '/Papierkorb' },
    });

    return this.prisma.cloudFile.update({
      where: { id: file.id },
      data: {
        folderId: trash?.id,
        deletedAt: new Date(),
      },
    });
  }

  async restore(currentUser: JwtPayload, fileId: string) {
    const file = await this.ensureOwnedOrManager(currentUser, fileId);
    const root = await this.prisma.cloudFolder.findFirst({
      where: { organizationId: currentUser.orgId, path: '/Dokumente' },
    });

    return this.prisma.cloudFile.update({
      where: { id: file.id },
      data: {
        deletedAt: null,
        folderId: root?.id,
      },
    });
  }

  async hardDelete(currentUser: JwtPayload, fileId: string) {
    const file = await this.ensureOwnedOrManager(currentUser, fileId);

    await this.prisma.$transaction(async (tx) => {
      await tx.cloudFile.delete({ where: { id: file.id } });
      await tx.teamQuota.update({
        where: { organizationId: currentUser.orgId },
        data: {
          usedBytes: {
            decrement: file.sizeBytes,
          },
        },
      });
    });

    await this.storageService.deleteObject(file.storageKey);
    return { success: true };
  }

  async share(currentUser: JwtPayload, fileId: string, userIds: string[]) {
    const file = await this.ensureOwnedOrManager(currentUser, fileId);
    return this.prisma.cloudFile.update({
      where: { id: file.id },
      data: {
        visibility: userIds.length > 0 ? FileVisibility.EXPLICIT : FileVisibility.TEAM,
        explicitShareIds: userIds,
      },
    });
  }

  async largestFiles(currentUser: JwtPayload, limit = 20) {
    return this.prisma.cloudFile.findMany({
      where: { organizationId: currentUser.orgId, deletedAt: null },
      orderBy: { sizeBytes: 'desc' },
      take: limit,
    });
  }

  async oldestFiles(currentUser: JwtPayload, limit = 20) {
    return this.prisma.cloudFile.findMany({
      where: { organizationId: currentUser.orgId, deletedAt: null },
      orderBy: { createdAt: 'asc' },
      take: limit,
    });
  }

  private async ensureDefaultFolderStructure(organizationId: string) {
    for (const path of DEFAULT_FOLDERS) {
      const name = path.split('/').filter(Boolean).pop()!;
      const exists = await this.prisma.cloudFolder.findFirst({
        where: { organizationId, path },
      });
      if (!exists) {
        await this.prisma.cloudFolder.create({
          data: {
            organizationId,
            name,
            path,
          },
        });
      }
    }
  }

  private async ensureTeamQuota(organizationId: string) {
    const quotaBytes = BigInt(this.configService.get<number>('TEAM_STORAGE_QUOTA_BYTES', 5_368_709_120));
    return this.prisma.teamQuota.upsert({
      where: { organizationId },
      create: {
        organizationId,
        quotaBytes,
        usedBytes: BigInt(0),
      },
      update: {},
    });
  }

  private normalizePath(parentPath: string, folderName: string) {
    const cleanParent = parentPath.endsWith('/') ? parentPath.slice(0, -1) : parentPath;
    const normalized = `${cleanParent}/${folderName}`.replace(/\/+/g, '/');
    return normalized.startsWith('/') ? normalized : `/${normalized}`;
  }

  private async findParentFolderId(organizationId: string, parentPath: string) {
    const parent = await this.prisma.cloudFolder.findFirst({
      where: { organizationId, path: parentPath },
      select: { id: true },
    });
    return parent?.id;
  }

  private fileExtension(filename: string): string {
    const index = filename.lastIndexOf('.');
    return index === -1 ? '' : filename.slice(index);
  }

  private canManageFiles(currentUser: JwtPayload) {
    return currentUser.roles.some((role) =>
      ['ADMIN', 'TRAINER', 'TEAM_MANAGER', 'ANALYST'].includes(role),
    );
  }

  private async ensureFileAccess(currentUser: JwtPayload, fileId: string) {
    const file = await this.prisma.cloudFile.findUnique({ where: { id: fileId } });
    if (!file || file.organizationId !== currentUser.orgId) {
      throw new NotFoundException('Datei nicht gefunden');
    }

    if (this.canManageFiles(currentUser)) {
      return file;
    }

    if (file.ownerUserId === currentUser.sub || file.explicitShareIds.includes(currentUser.sub)) {
      return file;
    }

    if (file.visibility === FileVisibility.TEAM && (!file.teamId || currentUser.teamIds.includes(file.teamId))) {
      return file;
    }

    throw new ForbiddenException('Keine Berechtigung');
  }

  private async ensureOwnedOrManager(currentUser: JwtPayload, fileId: string) {
    const file = await this.ensureFileAccess(currentUser, fileId);
    if (file.ownerUserId !== currentUser.sub && !this.canManageFiles(currentUser)) {
      throw new ForbiddenException('Keine Berechtigung zum Bearbeiten');
    }
    return file;
  }
}
