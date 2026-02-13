import { getPrisma } from '../../lib/prisma';
import { hashPassword, verifyPassword } from '../../lib/password';
import {
  signAccessToken,
  signRefreshToken,
  verifyRefreshToken,
  generateTokenId,
} from '../../lib/jwt';
import { AppError } from '../../middleware/errorHandler';
import type { RegisterInput, LoginInput } from './auth.schema';

interface TokenConfig {
  accessSecret: string;
  refreshSecret: string;
  accessTtl: string;
  refreshTtl: string;
}

function parseDurationMs(duration: string): number {
  const match = duration.match(/^(\d+)(s|m|h|d)$/);
  if (!match) return 30 * 24 * 60 * 60 * 1000; // default 30d
  const value = parseInt(match[1], 10);
  switch (match[2]) {
    case 's': return value * 1000;
    case 'm': return value * 60 * 1000;
    case 'h': return value * 60 * 60 * 1000;
    case 'd': return value * 24 * 60 * 60 * 1000;
    default: return 30 * 24 * 60 * 60 * 1000;
  }
}

function sanitizeUser(user: {
  id: string;
  email: string;
  firstName: string | null;
  lastName: string | null;
  role: string;
  clubId: string | null;
  teamId: string | null;
  onboardingCompleted: boolean;
  createdAt: Date;
}) {
  return {
    id: user.id,
    email: user.email,
    firstName: user.firstName,
    lastName: user.lastName,
    role: user.role,
    clubId: user.clubId,
    teamId: user.teamId,
    onboardingCompleted: user.onboardingCompleted,
    createdAt: user.createdAt.toISOString(),
  };
}

function computeOnboardingRequired(user: { clubId: string | null; teamId: string | null; onboardingCompleted: boolean }): boolean {
  // Onboarding is required if user has not completed it OR is missing club/team assignment
  return !user.onboardingCompleted || !user.clubId || !user.teamId;
}

async function issueTokenPair(userId: string, email: string, role: string, config: TokenConfig) {
  const prisma = getPrisma();

  // Create access token
  const accessToken = signAccessToken(
    { userId, email, role },
    config.accessSecret,
    config.accessTtl
  );

  // Create refresh token with rotation
  const tokenId = generateTokenId();
  const refreshTtlMs = parseDurationMs(config.refreshTtl);
  const expiresAt = new Date(Date.now() + refreshTtlMs);

  const refreshTokenRecord = await prisma.refreshToken.create({
    data: {
      id: tokenId,
      token: signRefreshToken({ userId, tokenId }, config.refreshSecret, config.refreshTtl),
      userId,
      expiresAt,
    },
  });

  return {
    accessToken,
    refreshToken: refreshTokenRecord.token,
    expiresIn: config.accessTtl,
  };
}

export async function register(input: RegisterInput, config: TokenConfig) {
  const prisma = getPrisma();
  const email = input.email.trim().toLowerCase();

  const existing = await prisma.user.findUnique({ where: { email } });
  if (existing) {
    throw new AppError(409, 'EMAIL_TAKEN', 'Email is already registered');
  }

  const passwordHash = await hashPassword(input.password);

  const user = await prisma.user.create({
    data: {
      email,
      passwordHash,
      firstName: input.firstName ?? null,
      lastName: input.lastName ?? null,
      role: input.role ?? 'trainer',
      onboardingCompleted: false,
    },
  });

  const tokens = await issueTokenPair(user.id, user.email, user.role, config);

  return {
    ...tokens,
    user: sanitizeUser(user),
    onboardingRequired: true,
  };
}

export async function login(input: LoginInput, config: TokenConfig) {
  const prisma = getPrisma();
  const email = input.email.trim().toLowerCase();

  const user = await prisma.user.findUnique({ where: { email } });
  if (!user) {
    throw new AppError(401, 'INVALID_CREDENTIALS', 'Invalid email or password');
  }

  const valid = await verifyPassword(input.password, user.passwordHash);
  if (!valid) {
    throw new AppError(401, 'INVALID_CREDENTIALS', 'Invalid email or password');
  }

  const tokens = await issueTokenPair(user.id, user.email, user.role, config);

  return {
    ...tokens,
    user: sanitizeUser(user),
    onboardingRequired: computeOnboardingRequired(user),
  };
}

export async function refresh(rawRefreshToken: string, config: TokenConfig) {
  const prisma = getPrisma();

  // Verify JWT signature
  let payload: { userId: string; tokenId: string };
  try {
    payload = verifyRefreshToken(rawRefreshToken, config.refreshSecret);
  } catch {
    throw new AppError(401, 'INVALID_REFRESH_TOKEN', 'Invalid or expired refresh token');
  }

  // Find the token record in DB
  const tokenRecord = await prisma.refreshToken.findUnique({
    where: { id: payload.tokenId },
  });

  if (!tokenRecord) {
    throw new AppError(401, 'INVALID_REFRESH_TOKEN', 'Refresh token not found');
  }

  // Check if already revoked (token reuse detection)
  if (tokenRecord.revokedAt) {
    // Possible token theft — revoke ALL tokens for this user
    await prisma.refreshToken.updateMany({
      where: { userId: tokenRecord.userId, revokedAt: null },
      data: { revokedAt: new Date() },
    });
    throw new AppError(401, 'TOKEN_REUSED', 'Refresh token has been revoked. All sessions invalidated.');
  }

  // Check expiry
  if (tokenRecord.expiresAt < new Date()) {
    await prisma.refreshToken.update({
      where: { id: tokenRecord.id },
      data: { revokedAt: new Date() },
    });
    throw new AppError(401, 'EXPIRED_REFRESH_TOKEN', 'Refresh token has expired');
  }

  // Revoke the used token (rotation)
  await prisma.refreshToken.update({
    where: { id: tokenRecord.id },
    data: { revokedAt: new Date() },
  });

  // Fetch user to get current state
  const user = await prisma.user.findUnique({ where: { id: payload.userId } });
  if (!user) {
    throw new AppError(401, 'USER_NOT_FOUND', 'User no longer exists');
  }

  // Issue new pair
  const tokens = await issueTokenPair(user.id, user.email, user.role, config);

  return {
    ...tokens,
    user: sanitizeUser(user),
    onboardingRequired: computeOnboardingRequired(user),
  };
}

export async function getMe(userId: string) {
  const prisma = getPrisma();

  const user = await prisma.user.findUnique({
    where: { id: userId },
    select: {
      id: true,
      email: true,
      firstName: true,
      lastName: true,
      role: true,
      clubId: true,
      teamId: true,
      onboardingCompleted: true,
      createdAt: true,
      club: { select: { id: true, name: true, region: true } },
      team: { select: { id: true, name: true } },
    },
  });

  if (!user) {
    throw new AppError(404, 'USER_NOT_FOUND', 'User not found');
  }

  return {
    user: {
      id: user.id,
      email: user.email,
      firstName: user.firstName,
      lastName: user.lastName,
      role: user.role,
      clubId: user.clubId,
      teamId: user.teamId,
      onboardingCompleted: user.onboardingCompleted,
      createdAt: user.createdAt.toISOString(),
      club: user.club,
      team: user.team,
    },
    onboardingRequired: computeOnboardingRequired(user),
  };
}

export async function deleteAccount(userId: string) {
  const prisma = getPrisma();

  await prisma.refreshToken.deleteMany({ where: { userId } });
  await prisma.user.delete({ where: { id: userId } });
}

export async function logout(userId: string, rawRefreshToken?: string) {
  const prisma = getPrisma();

  if (rawRefreshToken) {
    // Revoke specific refresh token
    await prisma.refreshToken.updateMany({
      where: { token: rawRefreshToken, userId, revokedAt: null },
      data: { revokedAt: new Date() },
    });
  } else {
    // Revoke all refresh tokens for this user
    await prisma.refreshToken.updateMany({
      where: { userId, revokedAt: null },
      data: { revokedAt: new Date() },
    });
  }
}
