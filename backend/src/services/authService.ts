import bcrypt from 'bcryptjs';
import { UserRole } from '@prisma/client';
import { prisma } from '../prisma/client';
import { signAccessToken } from '../config/jwt';
import { AppError } from '../middleware/errorHandler';

const BCRYPT_ROUNDS = 12;

type RegisterInput = {
  email: string;
  password: string;
  role: UserRole;
};

type LoginInput = {
  email: string;
  password: string;
};

function normalizeEmail(email: string): string {
  return email.trim().toLowerCase();
}

function assertStrongPassword(password: string): void {
  if (password.length < 8) {
    throw new AppError(400, 'INVALID_PASSWORD', 'Password must be at least 8 characters long');
  }
}

function toAuthUser(user: {
  id: string;
  email: string;
  role: UserRole;
  clubId: string | null;
  teamId: string | null;
  onboardingCompleted: boolean;
}) {
  return {
    id: user.id,
    email: user.email,
    role: user.role,
    clubId: user.clubId,
    teamId: user.teamId,
    onboardingCompleted: user.onboardingCompleted,
  };
}

export async function registerUser(input: RegisterInput, jwtSecret: string) {
  const email = normalizeEmail(input.email);
  assertStrongPassword(input.password);

  const existing = await prisma.user.findUnique({ where: { email } });
  if (existing) {
    throw new AppError(409, 'EMAIL_TAKEN', 'Email is already registered');
  }

  const passwordHash = await bcrypt.hash(input.password, BCRYPT_ROUNDS);
  const user = await prisma.user.create({
    data: {
      email,
      passwordHash,
      role: input.role,
      onboardingCompleted: false,
    },
  });

  const token = signAccessToken(
    {
      userId: user.id,
      email: user.email,
      role: user.role,
    },
    jwtSecret
  );

  return {
    token,
    user: toAuthUser(user),
  };
}

export async function loginUser(input: LoginInput, jwtSecret: string) {
  const email = normalizeEmail(input.email);
  const user = await prisma.user.findUnique({ where: { email } });

  if (!user) {
    throw new AppError(401, 'INVALID_CREDENTIALS', 'Invalid email or password');
  }

  const isPasswordValid = await bcrypt.compare(input.password, user.passwordHash);
  if (!isPasswordValid) {
    throw new AppError(401, 'INVALID_CREDENTIALS', 'Invalid email or password');
  }

  const token = signAccessToken(
    {
      userId: user.id,
      email: user.email,
      role: user.role,
    },
    jwtSecret
  );

  return {
    token,
    user: toAuthUser(user),
  };
}

export async function getAuthenticatedUser(userId: string) {
  const user = await prisma.user.findUnique({
    where: { id: userId },
    select: {
      id: true,
      email: true,
      role: true,
      clubId: true,
      teamId: true,
      onboardingCompleted: true,
    },
  });

  if (!user) {
    throw new AppError(404, 'USER_NOT_FOUND', 'User not found');
  }

  return user;
}
