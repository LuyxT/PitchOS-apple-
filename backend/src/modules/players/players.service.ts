import { getPrisma } from '../../lib/prisma';
import { AppError } from '../../middleware/errorHandler';
import type { CreatePlayerInput } from './players.schema';

async function resolveTeamId(input: CreatePlayerInput, userId: string): Promise<string | null> {
  const prisma = getPrisma();

  // If teamId provided directly, use it
  if (input.teamId) {
    const team = await prisma.team.findUnique({ where: { id: input.teamId } });
    if (team) return team.id;
  }

  // Try to resolve via the user's assigned team
  const user = await prisma.user.findUnique({
    where: { id: userId },
    select: { teamId: true, clubId: true },
  });

  if (user?.teamId) {
    return user.teamId;
  }

  // If teamName is provided, find or create team under the user's club
  if (input.teamName) {
    const clubId = user?.clubId;

    if (clubId) {
      // Look for existing team with that name in the club
      const existing = await prisma.team.findFirst({
        where: { name: input.teamName, clubId },
      });
      if (existing) return existing.id;

      // Create a new team under the club
      const newTeam = await prisma.team.create({
        data: { name: input.teamName, clubId },
      });
      return newTeam.id;
    }

    // No club — create a default club, then create the team
    const club = await prisma.club.create({
      data: { name: 'Mein Verein', region: 'Unbekannt' },
    });

    // Assign club to user
    await prisma.user.update({
      where: { id: userId },
      data: { clubId: club.id },
    });

    const newTeam = await prisma.team.create({
      data: { name: input.teamName, clubId: club.id },
    });

    // Assign team to user
    await prisma.user.update({
      where: { id: userId },
      data: { teamId: newTeam.id },
    });

    return newTeam.id;
  }

  return null;
}

export async function createPlayer(input: CreatePlayerInput, userId: string) {
  const prisma = getPrisma();

  const teamId = await resolveTeamId(input, userId);

  const player = await prisma.player.create({
    data: {
      name: input.name,
      number: input.number ?? 0,
      position: input.position,
      status: input.status ?? 'available',
      dateOfBirth: input.dateOfBirth ? new Date(input.dateOfBirth) : null,
      secondaryPositions: input.secondaryPositions ?? [],
      heightCm: input.heightCm ?? null,
      weightKg: input.weightKg ?? null,
      preferredFoot: input.preferredFoot ?? null,
      teamName: input.teamName ?? '',
      squadStatus: input.squadStatus ?? 'active',
      joinedAt: input.joinedAt ? new Date(input.joinedAt) : null,
      roles: input.roles ?? [],
      groups: input.groups ?? [],
      injuryStatus: input.injuryStatus ?? 'fit',
      notes: input.notes ?? '',
      developmentGoals: input.developmentGoals ?? '',
      teamId: teamId ?? undefined,
    },
  });

  return formatPlayerResponse(player);
}

export async function listPlayers(teamId?: string) {
  const prisma = getPrisma();

  const players = await prisma.player.findMany({
    where: teamId ? { teamId } : undefined,
    orderBy: { createdAt: 'desc' },
  });

  return players.map(formatPlayerResponse);
}

export async function getPlayerById(playerId: string) {
  const prisma = getPrisma();

  const player = await prisma.player.findUnique({ where: { id: playerId } });
  if (!player) {
    throw new AppError(404, 'PLAYER_NOT_FOUND', 'Player not found');
  }

  return formatPlayerResponse(player);
}

export async function deletePlayer(playerId: string) {
  const prisma = getPrisma();

  const existing = await prisma.player.findUnique({ where: { id: playerId } });
  if (!existing) {
    throw new AppError(404, 'PLAYER_NOT_FOUND', 'Player not found');
  }

  await prisma.player.delete({ where: { id: playerId } });
}

function formatPlayerResponse(player: {
  id: string;
  name: string;
  number: number;
  position: string;
  status: string;
  dateOfBirth: Date | null;
  secondaryPositions: string[];
  heightCm: number | null;
  weightKg: number | null;
  preferredFoot: string | null;
  teamName: string;
  squadStatus: string;
  joinedAt: Date | null;
  roles: string[];
  groups: string[];
  injuryStatus: string;
  notes: string;
  developmentGoals: string;
  teamId: string | null;
  createdAt: Date;
  updatedAt: Date;
}) {
  return {
    id: player.id,
    name: player.name,
    number: player.number,
    position: player.position,
    status: player.status,
    dateOfBirth: player.dateOfBirth?.toISOString() ?? null,
    secondaryPositions: player.secondaryPositions,
    heightCm: player.heightCm,
    weightKg: player.weightKg,
    preferredFoot: player.preferredFoot,
    teamName: player.teamName,
    squadStatus: player.squadStatus,
    joinedAt: player.joinedAt?.toISOString() ?? null,
    roles: player.roles,
    groups: player.groups,
    injuryStatus: player.injuryStatus,
    notes: player.notes,
    developmentGoals: player.developmentGoals,
    teamId: player.teamId,
    createdAt: player.createdAt.toISOString(),
    updatedAt: player.updatedAt.toISOString(),
  };
}
