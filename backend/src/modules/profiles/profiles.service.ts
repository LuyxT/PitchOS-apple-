import { getPrisma } from '../../lib/prisma';
import { AppError } from '../../middleware/errorHandler';

/* ── DTO mappers ── */

interface PersonProfileRow {
  id: string;
  userId: string;
  displayName: string;
  linkedPlayerID: string | null;
  linkedAdminPersonID: string | null;
  core: unknown;
  player: unknown;
  headCoach: unknown;
  assistantCoach: unknown;
  athleticCoach: unknown;
  medical: unknown;
  teamManager: unknown;
  board: unknown;
  facility: unknown;
  lockedFieldKeys: unknown;
  updatedBy: string;
  createdAt: Date;
  updatedAt: Date;
}

function toPersonProfileDTO(p: PersonProfileRow) {
  return {
    id: p.id,
    linkedPlayerID: p.linkedPlayerID,
    linkedAdminPersonID: p.linkedAdminPersonID,
    core: p.core ?? {},
    player: p.player ?? null,
    headCoach: p.headCoach ?? null,
    assistantCoach: p.assistantCoach ?? null,
    athleticCoach: p.athleticCoach ?? null,
    medical: p.medical ?? null,
    teamManager: p.teamManager ?? null,
    board: p.board ?? null,
    facility: p.facility ?? null,
    lockedFieldKeys: Array.isArray(p.lockedFieldKeys) ? p.lockedFieldKeys : [],
    updatedAt: p.updatedAt.toISOString(),
    updatedBy: p.updatedBy,
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
    profileID: e.profileId,
    actorName: e.actorName,
    fieldPath: e.fieldPath,
    area: e.area,
    oldValue: e.oldValue ?? '-',
    newValue: e.newValue ?? '-',
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
  return profiles.map((p) => toPersonProfileDTO(p as unknown as PersonProfileRow));
}

export async function createProfile(
  userId: string,
  input: {
    linkedPlayerID?: string | null;
    linkedAdminPersonID?: string | null;
    displayName?: string;
    core?: unknown;
    player?: unknown;
    headCoach?: unknown;
    assistantCoach?: unknown;
    athleticCoach?: unknown;
    medical?: unknown;
    teamManager?: unknown;
    board?: unknown;
    facility?: unknown;
    lockedFieldKeys?: unknown;
    updatedBy?: string;
  },
) {
  const prisma = getPrisma();
  const core = (input.core as Record<string, unknown>) ?? {};
  const displayName =
    input.displayName ||
    [core.firstName, core.lastName].filter(Boolean).join(' ') ||
    'Unnamed';

  const profile = await prisma.personProfile.create({
    data: {
      userId,
      displayName,
      linkedPlayerID: input.linkedPlayerID ?? null,
      linkedAdminPersonID: input.linkedAdminPersonID ?? null,
      core: input.core ?? undefined,
      player: input.player ?? undefined,
      headCoach: input.headCoach ?? undefined,
      assistantCoach: input.assistantCoach ?? undefined,
      athleticCoach: input.athleticCoach ?? undefined,
      medical: input.medical ?? undefined,
      teamManager: input.teamManager ?? undefined,
      board: input.board ?? undefined,
      facility: input.facility ?? undefined,
      lockedFieldKeys: Array.isArray(input.lockedFieldKeys) ? input.lockedFieldKeys : [],
      updatedBy: input.updatedBy ?? 'System',
    },
  });
  return toPersonProfileDTO(profile as unknown as PersonProfileRow);
}

export async function updateProfile(
  userId: string,
  profileId: string,
  input: {
    linkedPlayerID?: string | null;
    linkedAdminPersonID?: string | null;
    displayName?: string;
    core?: unknown;
    player?: unknown;
    headCoach?: unknown;
    assistantCoach?: unknown;
    athleticCoach?: unknown;
    medical?: unknown;
    teamManager?: unknown;
    board?: unknown;
    facility?: unknown;
    lockedFieldKeys?: unknown;
    updatedBy?: string;
  },
) {
  const prisma = getPrisma();

  const existing = await prisma.personProfile.findUnique({ where: { id: profileId } });
  if (!existing || existing.userId !== userId) {
    throw new AppError(404, 'PROFILE_NOT_FOUND', 'Profile not found');
  }

  // Resolve actor name for audit
  const actorName = input.updatedBy ?? 'System';

  // Detect changed fields and create audit entries
  const changes: { fieldPath: string; area: string; oldValue: string | null; newValue: string | null }[] = [];

  const core = (input.core as Record<string, unknown>) ?? {};
  const displayName =
    input.displayName ||
    [core.firstName, core.lastName].filter(Boolean).join(' ') ||
    existing.displayName;

  if (displayName !== existing.displayName) {
    changes.push({
      fieldPath: 'core.displayName',
      area: 'core',
      oldValue: existing.displayName,
      newValue: displayName,
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

  const updated = await prisma.$transaction(async (tx) => {
    const profile = await tx.personProfile.update({
      where: { id: profileId },
      data: {
        displayName,
        linkedPlayerID: input.linkedPlayerID ?? undefined,
        linkedAdminPersonID: input.linkedAdminPersonID ?? undefined,
        core: input.core ?? undefined,
        player: input.player ?? undefined,
        headCoach: input.headCoach ?? undefined,
        assistantCoach: input.assistantCoach ?? undefined,
        athleticCoach: input.athleticCoach ?? undefined,
        medical: input.medical ?? undefined,
        teamManager: input.teamManager ?? undefined,
        board: input.board ?? undefined,
        facility: input.facility ?? undefined,
        lockedFieldKeys: Array.isArray(input.lockedFieldKeys) ? input.lockedFieldKeys : undefined,
        updatedBy: input.updatedBy ?? undefined,
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

  return toPersonProfileDTO(updated as unknown as PersonProfileRow);
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
