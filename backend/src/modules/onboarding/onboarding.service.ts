import { getPrisma } from '../../lib/prisma';
import { AppError } from '../../middleware/errorHandler';
import type { OnboardingClubInput, OnboardingTeamInput } from './onboarding.schema';

export async function createOnboardingClub(userId: string, input: OnboardingClubInput) {
  const prisma = getPrisma();

  const result = await prisma.$transaction(async (tx) => {
    const club = await tx.club.create({
      data: {
        name: input.name,
        region: input.region,
        city: input.city,
      },
    });

    await tx.user.update({
      where: { id: userId },
      data: {
        clubId: club.id,
        onboardingCompleted: false,
      },
    });

    return club;
  });

  return {
    success: true,
    message: 'Club created successfully',
    onboardingRequired: true,
    nextStep: 'TEAM_SETUP',
    club: {
      id: result.id,
      name: result.name,
      city: result.city,
      region: result.region,
      league: null,
      inviteCode: null,
    },
  };
}

export async function createOnboardingTeam(userId: string, input: OnboardingTeamInput) {
  const prisma = getPrisma();

  const user = await prisma.user.findUnique({
    where: { id: userId },
    select: { clubId: true },
  });

  if (!user) {
    throw new AppError(404, 'USER_NOT_FOUND', 'User not found');
  }

  const resolvedClubId = input.clubId ?? user.clubId;
  if (!resolvedClubId) {
    throw new AppError(400, 'MISSING_CLUB', 'A club must be created before creating a team');
  }

  const club = await prisma.club.findUnique({ where: { id: resolvedClubId } });
  if (!club) {
    throw new AppError(404, 'CLUB_NOT_FOUND', 'Club not found');
  }

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
        // Do NOT set onboardingCompleted here — profile step still pending
      },
    });

    return team;
  });

  return {
    id: result.id,
    name: result.name,
    clubId: result.clubId,
    ageGroup: input.ageGroup ?? null,
    league: input.league ?? null,
  };
}
