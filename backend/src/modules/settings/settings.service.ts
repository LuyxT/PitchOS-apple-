import { getPrisma } from '../../lib/prisma';
import { hashPassword, verifyPassword } from '../../lib/password';
import { AppError } from '../../middleware/errorHandler';

// ─── DTOs ────────────────────────────────────────────────

interface SecuritySessionDTO {
  id: string;
  deviceName: string;
  platformName: string;
  lastUsedAt: string;
  ipAddress: string;
  location: string;
  isCurrentDevice: boolean;
}

interface SecurityTokenDTO {
  id: string;
  name: string;
  scope: string;
  lastUsedAt: string | null;
  createdAt: string;
}

interface SecuritySettingsDTO {
  twoFactorEnabled: boolean;
  sessions: SecuritySessionDTO[];
  apiTokens: SecurityTokenDTO[];
  privacyURL: string;
}

interface AppInfoSettingsDTO {
  version: string;
  buildNumber: string;
  lastUpdateAt: string;
  updateState: string;
  changelog: string[];
}

interface AccountContextDTO {
  id: string;
  clubName: string;
  teamName: string;
  roleTitle: string;
  isCurrent: boolean;
}

interface AccountSettingsDTO {
  contexts: AccountContextDTO[];
  selectedContextID: string | null;
  canDeactivateAccount: boolean;
  canLeaveTeam: boolean;
}

interface PresentationSettingsDTO {
  language: string;
  region: string;
  timeZoneID: string;
  unitSystem: string;
  appearanceMode: string;
  contrastMode: string;
  uiScale: string;
  reduceAnimations: boolean;
  interactivePreviews: boolean;
}

interface NotificationModuleDTO {
  module: string;
  push: boolean;
  inApp: boolean;
  email: boolean;
}

interface NotificationSettingsDTO {
  globalEnabled: boolean;
  modules: NotificationModuleDTO[];
}

// ─── Helpers ─────────────────────────────────────────────

async function getOrCreateSettings(userId: string) {
  const prisma = getPrisma();

  return prisma.userSettings.upsert({
    where: { userId },
    create: {
      userId,
      presentation: {},
      notifications: {},
      security: {},
    },
    update: {},
  });
}

async function buildSecurityDTO(userId: string, currentTokenId?: string): Promise<SecuritySettingsDTO> {
  const prisma = getPrisma();

  const activeSessions = await prisma.refreshToken.findMany({
    where: {
      userId,
      revokedAt: null,
      expiresAt: { gt: new Date() },
    },
    orderBy: { createdAt: 'desc' },
  });

  return {
    twoFactorEnabled: false,
    sessions: activeSessions.map((session) => ({
      id: session.id,
      deviceName: 'Unknown Device',
      platformName: 'macOS',
      lastUsedAt: session.createdAt.toISOString(),
      ipAddress: '',
      location: '',
      isCurrentDevice: currentTokenId ? session.id === currentTokenId : false,
    })),
    apiTokens: [],
    privacyURL: '',
  };
}

function buildPresentationDTO(stored: Record<string, unknown>): PresentationSettingsDTO {
  return {
    language: (stored.language as string) ?? 'de',
    region: (stored.region as string) ?? 'DE',
    timeZoneID: (stored.timeZoneID as string) ?? 'Europe/Berlin',
    unitSystem: (stored.unitSystem as string) ?? 'metric',
    appearanceMode: (stored.appearanceMode as string) ?? 'light',
    contrastMode: (stored.contrastMode as string) ?? 'standard',
    uiScale: (stored.uiScale as string) ?? 'medium',
    reduceAnimations: (stored.reduceAnimations as boolean) ?? false,
    interactivePreviews: (stored.interactivePreviews as boolean) ?? true,
  };
}

function buildNotificationDTO(stored: Record<string, unknown>): NotificationSettingsDTO {
  return {
    globalEnabled: (stored.globalEnabled as boolean) ?? true,
    modules: Array.isArray(stored.modules) ? stored.modules : [],
  };
}

function buildAccountDTO(user: {
  id: string;
  email: string;
  role: string;
  teamId: string | null;
}, clubName?: string): AccountSettingsDTO {
  const roleTitleMap: Record<string, string> = {
    headCoach: 'Chef-Trainer',
    assistantCoach: 'Co-Trainer',
    player: 'Spieler',
    admin: 'Administrator',
    trainer: 'Trainer',
  };
  const roleTitle = roleTitleMap[user.role] ?? user.role;
  const teamName = user.teamId ?? '1. Mannschaft';

  return {
    contexts: [
      {
        id: user.id,
        clubName: clubName ?? '',
        teamName,
        roleTitle,
        isCurrent: true,
      },
    ],
    selectedContextID: user.id,
    canDeactivateAccount: true,
    canLeaveTeam: user.teamId != null,
  };
}

// ─── Bootstrap ───────────────────────────────────────────

export async function getBootstrap(userId: string) {
  const prisma = getPrisma();

  const settings = await getOrCreateSettings(userId);

  const user = await prisma.user.findUnique({
    where: { id: userId },
    include: {
      club: { select: { name: true } },
    },
  });

  if (!user) {
    throw new AppError(404, 'USER_NOT_FOUND', 'User not found');
  }

  const security = await buildSecurityDTO(userId);
  const presentation = buildPresentationDTO(
    (settings.presentation as Record<string, unknown>) ?? {},
  );
  const notifications = buildNotificationDTO(
    (settings.notifications as Record<string, unknown>) ?? {},
  );
  const account = buildAccountDTO(user, user.club?.name ?? '');

  return {
    presentation,
    notifications,
    security,
    appInfo: getAppInfo(),
    account,
  };
}

// ─── Presentation ────────────────────────────────────────

export async function savePresentation(userId: string, data: Record<string, unknown>) {
  const prisma = getPrisma();

  await getOrCreateSettings(userId);

  const updated = await prisma.userSettings.update({
    where: { userId },
    data: { presentation: data as any },
  });

  return updated.presentation;
}

// ─── Notifications ───────────────────────────────────────

export async function saveNotifications(userId: string, data: Record<string, unknown>) {
  const prisma = getPrisma();

  await getOrCreateSettings(userId);

  const updated = await prisma.userSettings.update({
    where: { userId },
    data: { notifications: data as any },
  });

  return updated.notifications;
}

// ─── Security ────────────────────────────────────────────

export async function getSecurity(userId: string): Promise<SecuritySettingsDTO> {
  return buildSecurityDTO(userId);
}

export async function changePassword(userId: string, currentPassword: string, newPassword: string) {
  const prisma = getPrisma();

  const user = await prisma.user.findUnique({
    where: { id: userId },
    select: { id: true, passwordHash: true },
  });

  if (!user) {
    throw new AppError(404, 'USER_NOT_FOUND', 'User not found');
  }

  const valid = await verifyPassword(currentPassword, user.passwordHash);
  if (!valid) {
    throw new AppError(400, 'INVALID_PASSWORD', 'Current password is incorrect');
  }

  const newHash = await hashPassword(newPassword);

  await prisma.user.update({
    where: { id: userId },
    data: { passwordHash: newHash },
  });

  return { success: true };
}

export async function updateTwoFactor(userId: string, _enabled: boolean): Promise<SecuritySettingsDTO> {
  // Placeholder — 2FA not yet implemented.
  // Return current security state unchanged.
  return buildSecurityDTO(userId);
}

export async function revokeSession(userId: string, sessionId: string): Promise<SecuritySettingsDTO> {
  const prisma = getPrisma();

  const token = await prisma.refreshToken.findFirst({
    where: { id: sessionId, userId, revokedAt: null },
  });

  if (!token) {
    throw new AppError(404, 'SESSION_NOT_FOUND', 'Session not found or already revoked');
  }

  await prisma.refreshToken.update({
    where: { id: token.id },
    data: { revokedAt: new Date() },
  });

  return buildSecurityDTO(userId);
}

export async function revokeAllSessions(userId: string, currentTokenId?: string): Promise<SecuritySettingsDTO> {
  const prisma = getPrisma();

  // Revoke every active session except the current one (if provided)
  const whereClause: {
    userId: string;
    revokedAt: null;
    id?: { not: string };
  } = {
    userId,
    revokedAt: null,
  };

  if (currentTokenId) {
    whereClause.id = { not: currentTokenId };
  }

  await prisma.refreshToken.updateMany({
    where: whereClause,
    data: { revokedAt: new Date() },
  });

  return buildSecurityDTO(userId, currentTokenId);
}

// ─── App Info ────────────────────────────────────────────

export function getAppInfo(): AppInfoSettingsDTO {
  return {
    version: '1.0.0',
    buildNumber: '1',
    lastUpdateAt: new Date().toISOString(),
    updateState: 'current',
    changelog: [],
  };
}

// ─── Feedback ────────────────────────────────────────────

export async function submitFeedback(
  userId: string,
  message: string,
  category?: string,
  rating?: number
) {
  const prisma = getPrisma();

  // Map to the existing Feedback model:
  //   message  -> summary
  //   category -> player (repurposed as a general-purpose label)
  //   rating   -> stored in the summary alongside the message when provided
  const summaryWithRating =
    rating !== undefined && rating !== null
      ? `${message} [rating: ${rating}]`
      : message;

  await prisma.feedback.create({
    data: {
      userId,
      player: category ?? 'general',
      summary: summaryWithRating,
      date: new Date(),
    },
  });

  return { success: true };
}

// ─── Account ─────────────────────────────────────────────

export async function switchAccountContext(
  userId: string,
  teamId?: string,
  role?: string
): Promise<AccountSettingsDTO> {
  const prisma = getPrisma();

  const data: { teamId?: string | null; role?: string } = {};
  if (teamId !== undefined) {
    data.teamId = teamId;
  }
  if (role !== undefined) {
    data.role = role;
  }

  const user = await prisma.user.update({
    where: { id: userId },
    data,
    include: { club: { select: { name: true } } },
  });

  return buildAccountDTO(user, user.club?.name ?? '');
}

export async function deactivateAccount(userId: string) {
  const prisma = getPrisma();

  // Revoke all tokens first, then delete the user
  await prisma.refreshToken.deleteMany({ where: { userId } });
  await prisma.userSettings.deleteMany({ where: { userId } });
  await prisma.user.delete({ where: { id: userId } });

  return { success: true };
}

export async function leaveTeam(userId: string) {
  const prisma = getPrisma();

  await prisma.user.update({
    where: { id: userId },
    data: { teamId: null },
  });

  return { success: true };
}
