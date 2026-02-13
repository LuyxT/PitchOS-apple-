import { getPrisma } from '../../lib/prisma';
import { AppError } from '../../middleware/errorHandler';
import type { CreateTeamInput } from './teams.schema';

export async function createTeam(userId: string, input: CreateTeamInput) {
  const prisma = getPrisma();

  // Resolve clubId: explicit > user's existing clubId
  const user = await prisma.user.findUnique({
    where: { id: userId },
    select: { id: true, clubId: true },
  });

  if (!user) {
    throw new AppError(404, 'USER_NOT_FOUND', 'User not found');
  }

  const resolvedClubId = input.clubId ?? user.clubId;
  if (!resolvedClubId) {
    throw new AppError(400, 'MISSING_CLUB', 'A club must be created before creating a team');
  }

  // Verify club exists
  const club = await prisma.club.findUnique({ where: { id: resolvedClubId } });
  if (!club) {
    throw new AppError(404, 'CLUB_NOT_FOUND', 'Club not found');
  }

  // Transaction: create team + update user atomically
  const result = await prisma.$transaction(async (tx) => {
    const team = await tx.team.create({
      data: {
        name: input.name,
        clubId: resolvedClubId,
      },
    });

    await tx.user.update({
      where: { id: userId },
      data: {
        clubId: resolvedClubId,
        teamId: team.id,
        onboardingCompleted: true,
      },
    });

    return team;
  });

  return result;
}

export async function getTeamById(teamId: string) {
  const prisma = getPrisma();

  const team = await prisma.team.findUnique({
    where: { id: teamId },
    include: {
      players: { select: { id: true, name: true, position: true, age: true } },
      club: { select: { id: true, name: true } },
    },
  });

  if (!team) {
    throw new AppError(404, 'TEAM_NOT_FOUND', 'Team not found');
  }

  return team;
}

export async function listTeamsByClub(clubId: string) {
  const prisma = getPrisma();
  return prisma.team.findMany({
    where: { clubId },
    orderBy: { createdAt: 'desc' },
    include: {
      players: { select: { id: true, name: true, position: true } },
    },
  });
}
