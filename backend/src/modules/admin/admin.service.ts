import { getPrisma } from '../../lib/prisma';
import { AppError } from '../../middleware/errorHandler';

// ─── DTO Types ──────────────────────────────────────────

export interface AdminPersonDTO {
  id: string;
  fullName: string;
  email: string | null;
  personType: string;
  role: string;
  teamName: string | null;
  groupIDs: string[];
  permissions: string[];
  presenceStatus: string | null;
  isOnline: boolean;
  linkedPlayerID: string | null;
  linkedMessengerUserID: string | null;
  lastActiveAt: string | null;
  createdAt: string;
  updatedAt: string;
}

export interface AdminGroupDTO {
  id: string;
  name: string;
  goal: string | null;
  groupType: string | null;
  memberIDs: string[];
  responsibleCoachID: string | null;
  assistantCoachID: string | null;
  startsAt: string | null;
  endsAt: string | null;
  createdAt: string;
  updatedAt: string;
}

export interface AdminInvitationDTO {
  id: string;
  recipientName: string;
  email: string;
  method: string | null;
  role: string;
  teamName: string | null;
  status: string;
  sentAt: string | null;
  expiresAt: string | null;
  acceptedAt: string | null;
  createdAt: string;
  updatedAt: string;
}

export interface AdminSeasonDTO {
  id: string;
  name: string;
  startsAt: string;
  endsAt: string;
  status: string;
  teamCount: number;
  playerCount: number;
  trainerCount: number;
  createdAt: string;
  updatedAt: string;
}

export interface AdminClubSettingsDTO {
  id: string;
  clubName: string | null;
  clubLogoPath: string | null;
  primaryColorHex: string | null;
  secondaryColorHex: string | null;
  standardTrainingTypes: string[];
  defaultVisibility: string | null;
  teamNameConvention: string | null;
  globalPermissions: string[];
}

export interface AdminMessengerRulesDTO {
  id: string;
  allowPrivatePlayerChat: boolean;
  allowDirectTrainerPlayerChat: boolean;
  defaultReadOnlyForPlayers: boolean;
  defaultGroups: string[];
  allowedChatTypes: string[];
  groupRuleDescription: string | null;
}

export interface AdminAuditEntryDTO {
  id: string;
  actorId: string | null;
  actorName: string | null;
  action: string;
  target: string | null;
  detail: string | null;
  area: string | null;
  createdAt: string;
}

// ─── Input Types ────────────────────────────────────────

export interface CreatePersonInput {
  fullName: string;
  email?: string | null;
  personType: string;
  role: string;
  teamName?: string | null;
  groupIDs?: string[];
  permissions?: string[];
  linkedPlayerID?: string | null;
  linkedMessengerUserID?: string | null;
}

export interface UpdatePersonInput extends Partial<CreatePersonInput> { }

export interface CreateGroupInput {
  name: string;
  goal?: string | null;
  groupType?: string | null;
  memberIDs?: string[];
  responsibleCoachID?: string | null;
  assistantCoachID?: string | null;
  startsAt?: string | null;
  endsAt?: string | null;
}

export interface UpdateGroupInput extends Partial<CreateGroupInput> { }

export interface CreateInvitationInput {
  recipientName: string;
  email: string;
  method?: string | null;
  role: string;
  teamName?: string | null;
  status?: string;
}

export interface CreateSeasonInput {
  name: string;
  startsAt: string;
  endsAt: string;
  status?: string;
}

export interface UpdateSeasonInput extends Partial<CreateSeasonInput> { }

export interface ClubSettingsInput {
  clubName?: string | null;
  clubLogoPath?: string | null;
  primaryColorHex?: string | null;
  secondaryColorHex?: string | null;
  standardTrainingTypes?: string[];
  defaultVisibility?: string | null;
  teamNameConvention?: string | null;
  globalPermissions?: string[];
}

export interface MessengerRulesInput {
  allowPrivatePlayerChat?: boolean;
  allowDirectTrainerPlayerChat?: boolean;
  defaultReadOnlyForPlayers?: boolean;
  defaultGroups?: string[];
  allowedChatTypes?: string[];
  groupRuleDescription?: string | null;
}

export interface AuditQueryInput {
  limit?: number;
  cursor?: string;
  person?: string;
  area?: string;
  from?: string;
  to?: string;
}

// ─── Tasks ──────────────────────────────────────────────

export async function listTasks(_userId: string) {
  return [];
}

// ─── Bootstrap ──────────────────────────────────────────

export async function getBootstrap(userId: string) {
  const prisma = getPrisma();

  const [persons, groups, invitations, seasons, clubSettings, messengerRules] =
    await Promise.all([
      prisma.adminPerson.findMany({ where: { userId }, orderBy: { createdAt: 'asc' } }),
      prisma.adminGroup.findMany({ where: { userId }, orderBy: { createdAt: 'asc' } }),
      prisma.adminInvitation.findMany({ where: { userId }, orderBy: { createdAt: 'desc' } }),
      prisma.adminSeason.findMany({ where: { userId }, orderBy: { startsAt: 'desc' } }),
      prisma.adminClubSettings.findFirst({ where: { userId } }),
      prisma.adminMessengerRules.findFirst({ where: { userId } }),
    ]);

  return {
    persons: persons.map(formatPerson),
    groups: groups.map(formatGroup),
    invitations: invitations.map(formatInvitation),
    seasons: seasons.map(formatSeason),
    clubSettings: clubSettings ? formatClubSettings(clubSettings) : null,
    messengerRules: messengerRules ? formatMessengerRules(messengerRules) : null,
  };
}

// ─── Persons ────────────────────────────────────────────

export async function createPerson(input: CreatePersonInput, userId: string): Promise<AdminPersonDTO> {
  const prisma = getPrisma();

  const person = await prisma.adminPerson.create({
    data: {
      fullName: input.fullName,
      email: input.email ?? null,
      personType: input.personType,
      role: input.role,
      teamName: input.teamName ?? null,
      groupIDs: input.groupIDs ?? [],
      permissions: input.permissions ?? [],
      linkedPlayerID: input.linkedPlayerID ?? null,
      linkedMessengerUserID: input.linkedMessengerUserID ?? null,
      userId,
    },
  });

  return formatPerson(person);
}

export async function updatePerson(
  personId: string,
  input: UpdatePersonInput,
  userId: string,
): Promise<AdminPersonDTO> {
  const prisma = getPrisma();

  const existing = await prisma.adminPerson.findUnique({ where: { id: personId } });
  if (!existing) {
    throw new AppError(404, 'PERSON_NOT_FOUND', 'Person not found');
  }
  if (existing.userId !== userId) {
    throw new AppError(403, 'FORBIDDEN', 'You do not have permission to update this person');
  }

  const data: Record<string, unknown> = {};
  if (input.fullName !== undefined) data.fullName = input.fullName;
  if (input.email !== undefined) data.email = input.email;
  if (input.personType !== undefined) data.personType = input.personType;
  if (input.role !== undefined) data.role = input.role;
  if (input.teamName !== undefined) data.teamName = input.teamName;
  if (input.groupIDs !== undefined) data.groupIDs = input.groupIDs;
  if (input.permissions !== undefined) data.permissions = input.permissions;
  if (input.linkedPlayerID !== undefined) data.linkedPlayerID = input.linkedPlayerID;
  if (input.linkedMessengerUserID !== undefined) data.linkedMessengerUserID = input.linkedMessengerUserID;

  const person = await prisma.adminPerson.update({
    where: { id: personId },
    data,
  });

  return formatPerson(person);
}

export async function deletePerson(personId: string, userId: string): Promise<void> {
  const prisma = getPrisma();

  const existing = await prisma.adminPerson.findUnique({ where: { id: personId } });
  if (!existing) {
    throw new AppError(404, 'PERSON_NOT_FOUND', 'Person not found');
  }
  if (existing.userId !== userId) {
    throw new AppError(403, 'FORBIDDEN', 'You do not have permission to delete this person');
  }

  await prisma.adminPerson.delete({ where: { id: personId } });
}

// ─── Groups ─────────────────────────────────────────────

export async function createGroup(input: CreateGroupInput, userId: string): Promise<AdminGroupDTO> {
  const prisma = getPrisma();

  const group = await prisma.adminGroup.create({
    data: {
      name: input.name,
      goal: input.goal ?? null,
      groupType: input.groupType ?? undefined,
      memberIDs: input.memberIDs ?? [],
      responsibleCoachID: input.responsibleCoachID ?? null,
      assistantCoachID: input.assistantCoachID ?? null,
      startsAt: input.startsAt ? new Date(input.startsAt) : null,
      endsAt: input.endsAt ? new Date(input.endsAt) : null,
      userId,
    },
  });

  return formatGroup(group);
}

export async function updateGroup(
  groupId: string,
  input: UpdateGroupInput,
  userId: string,
): Promise<AdminGroupDTO> {
  const prisma = getPrisma();

  const existing = await prisma.adminGroup.findUnique({ where: { id: groupId } });
  if (!existing) {
    throw new AppError(404, 'GROUP_NOT_FOUND', 'Group not found');
  }
  if (existing.userId !== userId) {
    throw new AppError(403, 'FORBIDDEN', 'You do not have permission to update this group');
  }

  const data: Record<string, unknown> = {};
  if (input.name !== undefined) data.name = input.name;
  if (input.goal !== undefined) data.goal = input.goal;
  if (input.groupType !== undefined) data.groupType = input.groupType;
  if (input.memberIDs !== undefined) data.memberIDs = input.memberIDs;
  if (input.responsibleCoachID !== undefined) data.responsibleCoachID = input.responsibleCoachID;
  if (input.assistantCoachID !== undefined) data.assistantCoachID = input.assistantCoachID;
  if (input.startsAt !== undefined) data.startsAt = input.startsAt ? new Date(input.startsAt) : null;
  if (input.endsAt !== undefined) data.endsAt = input.endsAt ? new Date(input.endsAt) : null;

  const group = await prisma.adminGroup.update({
    where: { id: groupId },
    data,
  });

  return formatGroup(group);
}

export async function deleteGroup(groupId: string, userId: string): Promise<void> {
  const prisma = getPrisma();

  const existing = await prisma.adminGroup.findUnique({ where: { id: groupId } });
  if (!existing) {
    throw new AppError(404, 'GROUP_NOT_FOUND', 'Group not found');
  }
  if (existing.userId !== userId) {
    throw new AppError(403, 'FORBIDDEN', 'You do not have permission to delete this group');
  }

  await prisma.adminGroup.delete({ where: { id: groupId } });
}

// ─── Invitations ────────────────────────────────────────

export async function createInvitation(
  input: CreateInvitationInput,
  userId: string,
): Promise<AdminInvitationDTO> {
  const prisma = getPrisma();

  const invitation = await prisma.adminInvitation.create({
    data: {
      recipientName: input.recipientName,
      email: input.email,
      method: input.method ?? undefined,
      role: input.role,
      teamName: input.teamName ?? null,
      status: input.status ?? 'pending',
      sentAt: new Date(),
      expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000), // 7 days
      userId,
    },
  });

  return formatInvitation(invitation);
}

export async function updateInvitationStatus(
  invitationId: string,
  status: string,
  userId: string,
): Promise<AdminInvitationDTO> {
  const prisma = getPrisma();

  const existing = await prisma.adminInvitation.findUnique({ where: { id: invitationId } });
  if (!existing) {
    throw new AppError(404, 'INVITATION_NOT_FOUND', 'Invitation not found');
  }
  if (existing.userId !== userId) {
    throw new AppError(403, 'FORBIDDEN', 'You do not have permission to update this invitation');
  }

  const data: Record<string, unknown> = { status };
  if (status === 'accepted') {
    data.acceptedAt = new Date();
  }

  const invitation = await prisma.adminInvitation.update({
    where: { id: invitationId },
    data,
  });

  return formatInvitation(invitation);
}

export async function resendInvitation(
  invitationId: string,
  userId: string,
): Promise<AdminInvitationDTO> {
  const prisma = getPrisma();

  const existing = await prisma.adminInvitation.findUnique({ where: { id: invitationId } });
  if (!existing) {
    throw new AppError(404, 'INVITATION_NOT_FOUND', 'Invitation not found');
  }
  if (existing.userId !== userId) {
    throw new AppError(403, 'FORBIDDEN', 'You do not have permission to resend this invitation');
  }

  const invitation = await prisma.adminInvitation.update({
    where: { id: invitationId },
    data: {
      sentAt: new Date(),
      expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
    },
  });

  return formatInvitation(invitation);
}

// ─── Audit ──────────────────────────────────────────────

export async function listAuditEntries(
  query: AuditQueryInput,
  userId: string,
): Promise<{ items: AdminAuditEntryDTO[]; nextCursor: string | null }> {
  const prisma = getPrisma();

  const take = query.limit ?? 50;

  const where: Record<string, unknown> = { userId };
  if (query.person) where.actorId = query.person;
  if (query.area) where.area = query.area;
  if (query.from || query.to) {
    const createdAt: Record<string, Date> = {};
    if (query.from) createdAt.gte = new Date(query.from);
    if (query.to) createdAt.lte = new Date(query.to);
    where.createdAt = createdAt;
  }

  const entries = await prisma.adminAuditEntry.findMany({
    where,
    orderBy: { createdAt: 'desc' },
    take: take + 1,
    ...(query.cursor ? { cursor: { id: query.cursor }, skip: 1 } : {}),
  });

  const hasMore = entries.length > take;
  const items = hasMore ? entries.slice(0, take) : entries;
  const nextCursor = hasMore ? items[items.length - 1].id : null;

  return {
    items: items.map(formatAuditEntry),
    nextCursor,
  };
}

// ─── Seasons ────────────────────────────────────────────

export async function createSeason(
  input: CreateSeasonInput,
  userId: string,
): Promise<AdminSeasonDTO> {
  const prisma = getPrisma();

  const season = await prisma.adminSeason.create({
    data: {
      name: input.name,
      startsAt: new Date(input.startsAt),
      endsAt: new Date(input.endsAt),
      status: input.status ?? 'draft',
      userId,
    },
  });

  return formatSeason(season);
}

export async function updateSeason(
  seasonId: string,
  input: UpdateSeasonInput,
  userId: string,
): Promise<AdminSeasonDTO> {
  const prisma = getPrisma();

  const existing = await prisma.adminSeason.findUnique({ where: { id: seasonId } });
  if (!existing) {
    throw new AppError(404, 'SEASON_NOT_FOUND', 'Season not found');
  }
  if (existing.userId !== userId) {
    throw new AppError(403, 'FORBIDDEN', 'You do not have permission to update this season');
  }

  const data: Record<string, unknown> = {};
  if (input.name !== undefined) data.name = input.name;
  if (input.startsAt !== undefined) data.startsAt = new Date(input.startsAt);
  if (input.endsAt !== undefined) data.endsAt = new Date(input.endsAt);
  if (input.status !== undefined) data.status = input.status;

  const season = await prisma.adminSeason.update({
    where: { id: seasonId },
    data,
  });

  return formatSeason(season);
}

export async function updateSeasonStatus(
  seasonId: string,
  status: string,
  userId: string,
): Promise<AdminSeasonDTO> {
  const prisma = getPrisma();

  const existing = await prisma.adminSeason.findUnique({ where: { id: seasonId } });
  if (!existing) {
    throw new AppError(404, 'SEASON_NOT_FOUND', 'Season not found');
  }
  if (existing.userId !== userId) {
    throw new AppError(403, 'FORBIDDEN', 'You do not have permission to update this season');
  }

  const season = await prisma.adminSeason.update({
    where: { id: seasonId },
    data: { status },
  });

  return formatSeason(season);
}

export async function activateSeason(
  seasonID: string,
  userId: string,
): Promise<{ success: true }> {
  const prisma = getPrisma();

  const season = await prisma.adminSeason.findUnique({ where: { id: seasonID } });
  if (!season) {
    throw new AppError(404, 'SEASON_NOT_FOUND', 'Season not found');
  }
  if (season.userId !== userId) {
    throw new AppError(403, 'FORBIDDEN', 'You do not have permission to activate this season');
  }

  // Deactivate all other seasons for this user, then activate the target
  await prisma.adminSeason.updateMany({
    where: { userId, status: 'active' },
    data: { status: 'inactive' },
  });

  await prisma.adminSeason.update({
    where: { id: seasonID },
    data: { status: 'active' },
  });

  return { success: true };
}

export async function duplicateRoster(
  _seasonId: string,
  _sourceSeasonID: string,
  _userId: string,
): Promise<{ success: true }> {
  // Placeholder implementation
  return { success: true };
}

// ─── Settings ───────────────────────────────────────────

export async function saveClubSettings(
  input: ClubSettingsInput,
  userId: string,
): Promise<AdminClubSettingsDTO> {
  const prisma = getPrisma();

  const settings = await prisma.adminClubSettings.upsert({
    where: { userId },
    create: {
      clubName: input.clubName ?? null,
      clubLogoPath: input.clubLogoPath ?? null,
      primaryColorHex: input.primaryColorHex ?? null,
      secondaryColorHex: input.secondaryColorHex ?? null,
      standardTrainingTypes: input.standardTrainingTypes ?? [],
      defaultVisibility: input.defaultVisibility ?? 'team',
      teamNameConvention: input.teamNameConvention ?? null,
      globalPermissions: input.globalPermissions ?? [],
      userId,
    },
    update: {
      ...(input.clubName !== undefined && { clubName: input.clubName ?? null }),
      ...(input.clubLogoPath !== undefined && { clubLogoPath: input.clubLogoPath ?? null }),
      ...(input.primaryColorHex !== undefined && { primaryColorHex: input.primaryColorHex ?? null }),
      ...(input.secondaryColorHex !== undefined && { secondaryColorHex: input.secondaryColorHex ?? null }),
      ...(input.standardTrainingTypes !== undefined && { standardTrainingTypes: input.standardTrainingTypes }),
      ...(input.defaultVisibility !== undefined && { defaultVisibility: input.defaultVisibility ?? 'team' }),
      ...(input.teamNameConvention !== undefined && { teamNameConvention: input.teamNameConvention ?? null }),
      ...(input.globalPermissions !== undefined && { globalPermissions: input.globalPermissions }),
    },
  });

  return formatClubSettings(settings);
}

export async function saveMessengerRules(
  input: MessengerRulesInput,
  userId: string,
): Promise<AdminMessengerRulesDTO> {
  const prisma = getPrisma();

  const rules = await prisma.adminMessengerRules.upsert({
    where: { userId },
    create: {
      allowPrivatePlayerChat: input.allowPrivatePlayerChat ?? false,
      allowDirectTrainerPlayerChat: input.allowDirectTrainerPlayerChat ?? false,
      defaultReadOnlyForPlayers: input.defaultReadOnlyForPlayers ?? false,
      defaultGroups: (input.defaultGroups ?? []) as any,
      allowedChatTypes: input.allowedChatTypes ?? [],
      groupRuleDescription: input.groupRuleDescription ?? null,
      userId,
    },
    update: {
      ...(input.allowPrivatePlayerChat !== undefined && { allowPrivatePlayerChat: input.allowPrivatePlayerChat }),
      ...(input.allowDirectTrainerPlayerChat !== undefined && { allowDirectTrainerPlayerChat: input.allowDirectTrainerPlayerChat }),
      ...(input.defaultReadOnlyForPlayers !== undefined && { defaultReadOnlyForPlayers: input.defaultReadOnlyForPlayers }),
      ...(input.defaultGroups !== undefined && { defaultGroups: input.defaultGroups as any }),
      ...(input.allowedChatTypes !== undefined && { allowedChatTypes: input.allowedChatTypes }),
      ...(input.groupRuleDescription !== undefined && { groupRuleDescription: input.groupRuleDescription }),
    },
  });

  return formatMessengerRules(rules);
}

// ─── Response formatters ────────────────────────────────

function formatPerson(person: {
  id: string;
  fullName: string;
  email: string | null;
  personType: string;
  role: string;
  teamName: string | null;
  groupIDs: string[];
  permissions: string[];
  presenceStatus: string | null;
  isOnline: boolean;
  linkedPlayerID: string | null;
  linkedMessengerUserID: string | null;
  lastActiveAt: Date | null;
  createdAt: Date;
  updatedAt: Date;
}): AdminPersonDTO {
  return {
    id: person.id,
    fullName: person.fullName,
    email: person.email,
    personType: person.personType,
    role: person.role,
    teamName: person.teamName,
    groupIDs: person.groupIDs,
    permissions: person.permissions,
    presenceStatus: person.presenceStatus,
    isOnline: person.isOnline,
    linkedPlayerID: person.linkedPlayerID,
    linkedMessengerUserID: person.linkedMessengerUserID,
    lastActiveAt: person.lastActiveAt?.toISOString() ?? null,
    createdAt: person.createdAt.toISOString(),
    updatedAt: person.updatedAt.toISOString(),
  };
}

function formatGroup(group: {
  id: string;
  name: string;
  goal: string | null;
  groupType: string | null;
  memberIDs: string[];
  responsibleCoachID: string | null;
  assistantCoachID: string | null;
  startsAt: Date | null;
  endsAt: Date | null;
  createdAt: Date;
  updatedAt: Date;
}): AdminGroupDTO {
  return {
    id: group.id,
    name: group.name,
    goal: group.goal,
    groupType: group.groupType,
    memberIDs: group.memberIDs,
    responsibleCoachID: group.responsibleCoachID,
    assistantCoachID: group.assistantCoachID,
    startsAt: group.startsAt?.toISOString() ?? null,
    endsAt: group.endsAt?.toISOString() ?? null,
    createdAt: group.createdAt.toISOString(),
    updatedAt: group.updatedAt.toISOString(),
  };
}

function formatInvitation(invitation: {
  id: string;
  recipientName: string;
  email: string;
  method: string | null;
  role: string;
  teamName: string | null;
  status: string;
  sentAt: Date | null;
  expiresAt: Date | null;
  acceptedAt: Date | null;
  createdAt: Date;
  updatedAt: Date;
}): AdminInvitationDTO {
  return {
    id: invitation.id,
    recipientName: invitation.recipientName,
    email: invitation.email,
    method: invitation.method,
    role: invitation.role,
    teamName: invitation.teamName,
    status: invitation.status,
    sentAt: invitation.sentAt?.toISOString() ?? null,
    expiresAt: invitation.expiresAt?.toISOString() ?? null,
    acceptedAt: invitation.acceptedAt?.toISOString() ?? null,
    createdAt: invitation.createdAt.toISOString(),
    updatedAt: invitation.updatedAt.toISOString(),
  };
}

function formatSeason(season: {
  id: string;
  name: string;
  startsAt: Date;
  endsAt: Date;
  status: string;
  teamCount: number;
  playerCount: number;
  trainerCount: number;
  createdAt: Date;
  updatedAt: Date;
}): AdminSeasonDTO {
  return {
    id: season.id,
    name: season.name,
    startsAt: season.startsAt.toISOString(),
    endsAt: season.endsAt.toISOString(),
    status: season.status,
    teamCount: season.teamCount,
    playerCount: season.playerCount,
    trainerCount: season.trainerCount,
    createdAt: season.createdAt.toISOString(),
    updatedAt: season.updatedAt.toISOString(),
  };
}

function formatClubSettings(settings: {
  id: string;
  clubName: string | null;
  clubLogoPath: string | null;
  primaryColorHex: string | null;
  secondaryColorHex: string | null;
  standardTrainingTypes: string[];
  defaultVisibility: string | null;
  teamNameConvention: string | null;
  globalPermissions: string[];
}): AdminClubSettingsDTO {
  return {
    id: settings.id,
    clubName: settings.clubName,
    clubLogoPath: settings.clubLogoPath,
    primaryColorHex: settings.primaryColorHex,
    secondaryColorHex: settings.secondaryColorHex,
    standardTrainingTypes: settings.standardTrainingTypes,
    defaultVisibility: settings.defaultVisibility,
    teamNameConvention: settings.teamNameConvention,
    globalPermissions: settings.globalPermissions,
  };
}

function formatMessengerRules(rules: {
  id: string;
  allowPrivatePlayerChat: boolean;
  allowDirectTrainerPlayerChat: boolean;
  defaultReadOnlyForPlayers: boolean;
  defaultGroups: unknown;
  allowedChatTypes: string[];
  groupRuleDescription: string | null;
}): AdminMessengerRulesDTO {
  return {
    id: rules.id,
    allowPrivatePlayerChat: rules.allowPrivatePlayerChat,
    allowDirectTrainerPlayerChat: rules.allowDirectTrainerPlayerChat,
    defaultReadOnlyForPlayers: rules.defaultReadOnlyForPlayers,
    defaultGroups: Array.isArray(rules.defaultGroups) ? rules.defaultGroups as string[] : [],
    allowedChatTypes: rules.allowedChatTypes,
    groupRuleDescription: rules.groupRuleDescription,
  };
}

function formatAuditEntry(entry: {
  id: string;
  actorId: string | null;
  actorName: string | null;
  action: string;
  target: string | null;
  detail: string | null;
  area: string | null;
  createdAt: Date;
}): AdminAuditEntryDTO {
  return {
    id: entry.id,
    actorId: entry.actorId,
    actorName: entry.actorName,
    action: entry.action,
    target: entry.target,
    detail: entry.detail,
    area: entry.area,
    createdAt: entry.createdAt.toISOString(),
  };
}
