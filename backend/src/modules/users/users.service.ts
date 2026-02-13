import { getPrisma } from '../../lib/prisma';
import { AppError } from '../../middleware/errorHandler';

export async function getUserById(userId: string) {
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

  return user;
}

export async function updateUserProfile(userId: string, data: { firstName?: string; lastName?: string }) {
  const prisma = getPrisma();

  const user = await prisma.user.update({
    where: { id: userId },
    data: {
      firstName: data.firstName,
      lastName: data.lastName,
    },
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
    },
  });

  return user;
}
