import { getPrisma } from '../../lib/prisma';
import { AppError } from '../../middleware/errorHandler';
import type { SaveProfileInput } from './profile.schema';

export async function saveProfile(userId: string, input: SaveProfileInput) {
  const prisma = getPrisma();

  const user = await prisma.user.update({
    where: { id: userId },
    data: {
      firstName: input.firstName ?? undefined,
      lastName: input.lastName ?? undefined,
      onboardingCompleted: true,
    },
    include: {
      club: { select: { name: true } },
    },
  });

  if (!user) {
    throw new AppError(404, 'USER_NOT_FOUND', 'User not found');
  }

  // Return PersonProfileDTO format expected by iOS
  return {
    id: user.id,
    linkedPlayerID: null,
    linkedAdminPersonID: null,
    core: {
      avatarPath: null,
      firstName: user.firstName ?? '',
      lastName: user.lastName ?? '',
      dateOfBirth: null,
      email: user.email,
      phone: null,
      clubName: user.club?.name ?? '',
      roles: [user.role],
      isActive: true,
      internalNotes: '',
    },
    player: null,
    headCoach: null,
    assistantCoach: null,
    athleticCoach: null,
    medical: null,
    teamManager: null,
    board: null,
    facility: null,
    lockedFieldKeys: [],
    updatedAt: user.updatedAt.toISOString(),
    updatedBy: 'system',
  };
}
