import { getPrisma } from '../../lib/prisma';
import { hashPassword, verifyPassword } from '../../lib/password';
import { AppError } from '../../middleware/errorHandler';

// ─── DTOs ────────────────────────────────────────────────

interface SessionDTO {
  id: string;
  deviceName: string;
  lastActiveAt: string;
  isCurrent: boolean;
}

interface SecuritySettingsDTO {
  twoFactorEnabled: boolean;
  activeSessions: SessionDTO[];
}

interface AppInfoSettingsDTO {
  appVersion: string;
  backendVersion: string;
  buildNumber: string;
  environment: string;
}

interface AccountSettingsDTO {
  userId: string;
  email: string;
  role: string;
  teamId: string | null;
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
    activeSessions: activeSessions.map((session) => ({
      id: session.id,
      deviceName: 'Unknown Device',
      lastActiveAt: session.createdAt.toISOString(),
      isCurrent: currentTokenId ? session.id === currentTokenId : false,
    })),
  };
}

// ─── Bootstrap ───────────────────────────────────────────

export async function getBootstrap(userId: string) {
  const prisma = getPrisma();

  const settings = await getOrCreateSettings(userId);

  const user = await prisma.user.findUnique({
    where: { id: userId },
    select: { id: true, email: true, role: true, teamId: true },
  });

  if (!user) {
    throw new AppError(404, 'USER_NOT_FOUND', 'User not found');
  }

  const security = await buildSecurityDTO(userId);

  return {
    presentation: settings.presentation as Record<string, unknown>,
    notifications: settings.notifications as Record<string, unknown>,
    security,
    appInfo: getAppInfo(),
    account: {
      userId: user.id,
      email: user.email,
      role: user.role,
      teamId: user.teamId,
    },
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
    appVersion: '1.0.0',
    backendVersion: '1.0.0',
    buildNumber: '1',
    environment: process.env.NODE_ENV ?? 'production',
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
    select: { id: true, email: true, role: true, teamId: true },
  });

  return {
    userId: user.id,
    email: user.email,
    role: user.role,
    teamId: user.teamId,
  };
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
