import { prisma } from '../prisma/client';
import { AppError } from '../middleware/errorHandler';

export async function createClub(userId: string, name: string, region: string) {
  const normalizedName = name.trim();
  const normalizedRegion = region.trim();

  if (!normalizedName) {
    throw new AppError(400, 'INVALID_CLUB_NAME', 'Club name is required');
  }

  if (!normalizedRegion) {
    throw new AppError(400, 'INVALID_CLUB_REGION', 'Club region is required');
  }

  const club = await prisma.club.create({
    data: {
      name: normalizedName,
      region: normalizedRegion,
    },
  });

  await prisma.user.update({
    where: { id: userId },
    data: {
      clubId: club.id,
      onboardingCompleted: false,
    },
  });

  return club;
}

export async function getClubById(clubId: string) {
  const club = await prisma.club.findUnique({ where: { id: clubId } });
  if (!club) {
    throw new AppError(404, 'CLUB_NOT_FOUND', 'Club not found');
  }
  return club;
}
