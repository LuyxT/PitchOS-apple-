import { getPrisma } from '../../lib/prisma';
import { AppError } from '../../middleware/errorHandler';

/* ── DTO mappers ── */

function toPersonProfileDTO(p: {
  id: string;
  userId: string;
  displayName: string;
  core: unknown;
  roleSpecific: unknown;
  createdAt: Date;
  updatedAt: Date;
}) {
  return {
    id: p.id,
    userId: p.userId,
    displayName: p.displayName,
    core: p.core,
    roleSpecific: p.roleSpecific,
    createdAt: p.createdAt.toISOString(),
    updatedAt: p.updatedAt.toISOString(),
  };
}

function toProfileAuditEntryDTO(e: {
  id: string;
  profileId: string;
  actorId: string;
  actorName: string;
  fieldPath: string;
  area: string;
  oldValue: string | null;
  newValue: string | null;
  timestamp: Date;
}) {
  return {
    id: e.id,
    profileId: e.profileId,
    actorId: e.actorId,
    actorName: e.actorName,
    fieldPath: e.fieldPath,
    area: e.area,
    oldValue: e.oldValue,
    newValue: e.newValue,
    timestamp: e.timestamp.toISOString(),
  };
}

/* ── Service functions ── */

export async function listProfiles(userId: string) {
  const prisma = getPrisma();
  const profiles = await prisma.personProfile.findMany({
    where: { userId },
    orderBy: { createdAt: 'desc' },
  });
  return profiles.map(toPersonProfileDTO);
}

export async function createProfile(
  userId: string,
  input: { displayName: string; core?: unknown; roleSpecific?: unknown },
) {
  const prisma = getPrisma();
  const profile = await prisma.personProfile.create({
    data: {
      userId,
      displayName: input.displayName,
      core: input.core ?? undefined,
      roleSpecific: input.roleSpecific ?? undefined,
    },
  });
  return toPersonProfileDTO(profile);
}

export async function updateProfile(
  userId: string,
  profileId: string,
  input: { displayName?: string; core?: unknown; roleSpecific?: unknown },
) {
  const prisma = getPrisma();

  const existing = await prisma.personProfile.findUnique({ where: { id: profileId } });
  if (!existing || existing.userId !== userId) {
    throw new AppError(404, 'PROFILE_NOT_FOUND', 'Profile not found');
  }

  // Resolve actor name for audit
  const user = await prisma.user.findUnique({ where: { id: userId }, select: { firstName: true, lastName: true } });
  const actorName = user ? [user.firstName, user.lastName].filter(Boolean).join(' ') || 'Unknown' : 'Unknown';

  // Detect changed fields and create audit entries
  const changes: { fieldPath: string; area: string; oldValue: string | null; newValue: string | null }[] = [];

  if (input.displayName !== undefined && input.displayName !== existing.displayName) {
    changes.push({
      fieldPath: 'displayName',
      area: 'general',
      oldValue: existing.displayName,
      newValue: input.displayName,
    });
  }
  if (input.core !== undefined) {
    changes.push({
      fieldPath: 'core',
      area: 'core',
      oldValue: JSON.stringify(existing.core),
      newValue: JSON.stringify(input.core),
    });
  }
  if (input.roleSpecific !== undefined) {
    changes.push({
      fieldPath: 'roleSpecific',
      area: 'roleSpecific',
      oldValue: JSON.stringify(existing.roleSpecific),
      newValue: JSON.stringify(input.roleSpecific),
    });
  }

  const updated = await prisma.$transaction(async (tx) => {
    const profile = await tx.personProfile.update({
      where: { id: profileId },
      data: {
        displayName: input.displayName,
        core: input.core ?? undefined,
        roleSpecific: input.roleSpecific ?? undefined,
      },
    });

    if (changes.length > 0) {
      await tx.profileAuditEntry.createMany({
        data: changes.map((c) => ({
          profileId,
          actorId: userId,
          actorName,
          fieldPath: c.fieldPath,
          area: c.area,
          oldValue: c.oldValue,
          newValue: c.newValue,
        })),
      });
    }

    return profile;
  });

  return toPersonProfileDTO(updated);
}

export async function deleteProfile(userId: string, profileId: string) {
  const prisma = getPrisma();

  const existing = await prisma.personProfile.findUnique({ where: { id: profileId } });
  if (!existing || existing.userId !== userId) {
    throw new AppError(404, 'PROFILE_NOT_FOUND', 'Profile not found');
  }

  await prisma.personProfile.delete({ where: { id: profileId } });
}

export async function listAuditEntries(userId: string, profileId?: string) {
  const prisma = getPrisma();

  // Only return audit entries for profiles owned by this user
  const userProfiles = await prisma.personProfile.findMany({
    where: { userId },
    select: { id: true },
  });
  const userProfileIds = userProfiles.map((p) => p.id);

  if (userProfileIds.length === 0) {
    return [];
  }

  const where: Record<string, unknown> = {
    profileId: profileId && userProfileIds.includes(profileId)
      ? profileId
      : { in: userProfileIds },
  };

  const entries = await prisma.profileAuditEntry.findMany({
    where,
    orderBy: { timestamp: 'desc' },
  });
  return entries.map(toProfileAuditEntryDTO);
}
