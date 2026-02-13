import { prisma } from '../prisma/client';
import { AppError } from '../middleware/errorHandler';

export async function createTeam(userId: string, name: string, clubId?: string) {
  const normalizedName = name.trim();

  if (!normalizedName) {
    throw new AppError(400, 'INVALID_TEAM_NAME', 'Team name is required');
  }

  const user = await prisma.user.findUnique({
    where: { id: userId },
    select: { id: true, clubId: true },
  });

  if (!user) {
    throw new AppError(404, 'USER_NOT_FOUND', 'User not found');
  }

  const resolvedClubId = clubId ?? user.clubId;
  if (!resolvedClubId) {
    throw new AppError(400, 'MISSING_CLUB', 'clubId is required before creating a team');
  }

  const club = await prisma.club.findUnique({ where: { id: resolvedClubId } });
  if (!club) {
    throw new AppError(404, 'CLUB_NOT_FOUND', 'Club not found');
  }

  const team = await prisma.team.create({
    data: {
      name: normalizedName,
      clubId: resolvedClubId,
    },
  });

  await prisma.user.update({
    where: { id: user.id },
    data: {
      clubId: resolvedClubId,
      teamId: team.id,
      onboardingCompleted: true,
    },
  });

  return team;
}

export async function getTeamById(teamId: string) {
  const team = await prisma.team.findUnique({ where: { id: teamId } });
  if (!team) {
    throw new AppError(404, 'TEAM_NOT_FOUND', 'Team not found');
  }
  return team;
}
