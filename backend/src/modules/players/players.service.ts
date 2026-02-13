import { getPrisma } from '../../lib/prisma';
import { AppError } from '../../middleware/errorHandler';
import type { CreatePlayerInput } from './players.schema';

export async function createPlayer(input: CreatePlayerInput) {
  const prisma = getPrisma();

  // Verify team exists
  const team = await prisma.team.findUnique({ where: { id: input.teamId } });
  if (!team) {
    throw new AppError(404, 'TEAM_NOT_FOUND', 'Team not found');
  }

  return prisma.player.create({
    data: {
      name: input.name,
      position: input.position,
      age: input.age,
      teamId: input.teamId,
    },
  });
}

export async function listPlayers(teamId?: string) {
  const prisma = getPrisma();

  return prisma.player.findMany({
    where: teamId ? { teamId } : undefined,
    orderBy: { createdAt: 'desc' },
  });
}

export async function getPlayerById(playerId: string) {
  const prisma = getPrisma();

  const player = await prisma.player.findUnique({ where: { id: playerId } });
  if (!player) {
    throw new AppError(404, 'PLAYER_NOT_FOUND', 'Player not found');
  }

  return player;
}

export async function deletePlayer(playerId: string) {
  const prisma = getPrisma();

  const existing = await prisma.player.findUnique({ where: { id: playerId } });
  if (!existing) {
    throw new AppError(404, 'PLAYER_NOT_FOUND', 'Player not found');
  }

  await prisma.player.delete({ where: { id: playerId } });
}
