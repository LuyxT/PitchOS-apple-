import { prisma } from '../prisma/client';
import { AppError } from '../middleware/errorHandler';

export async function createPlayer(input: {
  name: string;
  position: string;
  age: number;
  teamId: string;
}) {
  const name = input.name.trim();
  const position = input.position.trim();
  const age = Number(input.age);

  if (!name) {
    throw new AppError(400, 'INVALID_PLAYER_NAME', 'Player name is required');
  }

  if (!position) {
    throw new AppError(400, 'INVALID_PLAYER_POSITION', 'Player position is required');
  }

  if (!Number.isInteger(age) || age < 1 || age > 99) {
    throw new AppError(400, 'INVALID_PLAYER_AGE', 'Player age must be between 1 and 99');
  }

  const team = await prisma.team.findUnique({ where: { id: input.teamId } });
  if (!team) {
    throw new AppError(404, 'TEAM_NOT_FOUND', 'Team not found');
  }

  return prisma.player.create({
    data: {
      name,
      position,
      age,
      teamId: input.teamId,
    },
  });
}

export async function listPlayers(teamId?: string) {
  if (teamId) {
    return prisma.player.findMany({
      where: { teamId },
      orderBy: { createdAt: 'desc' },
    });
  }

  return prisma.player.findMany({
    orderBy: { createdAt: 'desc' },
  });
}

export async function deletePlayer(playerId: string) {
  const existing = await prisma.player.findUnique({ where: { id: playerId } });
  if (!existing) {
    throw new AppError(404, 'PLAYER_NOT_FOUND', 'Player not found');
  }

  await prisma.player.delete({ where: { id: playerId } });
}
