import { getPrisma } from '../../lib/prisma';
import { AppError } from '../../middleware/errorHandler';
import type { CreateClubInput } from './clubs.schema';

export async function createClub(userId: string, input: CreateClubInput) {
  const prisma = getPrisma();

  // Use a transaction to ensure both club creation and user update succeed together
  const result = await prisma.$transaction(async (tx) => {
    const club = await tx.club.create({
      data: {
        name: input.name,
        region: input.region,
      },
    });

    const user = await tx.user.update({
      where: { id: userId },
      data: {
        clubId: club.id,
        // Onboarding is not complete until team is also assigned
        onboardingCompleted: false,
      },
      select: {
        id: true,
        clubId: true,
        teamId: true,
        onboardingCompleted: true,
      },
    });

    return { club, user };
  });

  return result.club;
}

export async function getClubById(clubId: string) {
  const prisma = getPrisma();

  const club = await prisma.club.findUnique({
    where: { id: clubId },
    include: {
      teams: { select: { id: true, name: true } },
    },
  });

  if (!club) {
    throw new AppError(404, 'CLUB_NOT_FOUND', 'Club not found');
  }

  return club;
}

export async function listClubs() {
  const prisma = getPrisma();
  return prisma.club.findMany({
    orderBy: { createdAt: 'desc' },
    include: {
      teams: { select: { id: true, name: true } },
    },
  });
}
