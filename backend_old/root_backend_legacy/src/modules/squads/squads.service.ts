import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { JwtPayload } from '../auth/dto/jwt-payload.dto';
import { CreatePlayerDto } from './dto/create-player.dto';
import { UpdatePlayerDto } from './dto/update-player.dto';

@Injectable()
export class SquadsService {
  constructor(private readonly prisma: PrismaService) {}

  async list(currentUser: JwtPayload, teamId?: string, position?: string, fitness?: string) {
    const targetTeamIds = teamId ? [teamId] : currentUser.teamIds;

    return this.prisma.player.findMany({
      where: {
        teamId: { in: targetTeamIds },
        primaryPosition: position ?? undefined,
        fitnessStatus: fitness ?? undefined,
      },
      include: {
        user: {
          select: { id: true, firstName: true, lastName: true, email: true },
        },
      },
      orderBy: [{ teamId: 'asc' }, { primaryPosition: 'asc' }, { jerseyNumber: 'asc' }],
    });
  }

  async create(currentUser: JwtPayload, input: CreatePlayerDto) {
    return this.prisma.player.create({
      data: {
        teamId: input.teamId,
        userId: input.userId,
        primaryPosition: input.primaryPosition,
        secondaryPositions: input.secondaryPositions ?? [],
        jerseyNumber: input.jerseyNumber,
        fitnessStatus: input.fitnessStatus ?? 'fit',
        squadStatus: input.squadStatus ?? 'active',
        availabilityStatus: input.availabilityStatus ?? 'available',
      },
      include: { user: true, team: true },
    });
  }

  async update(currentUser: JwtPayload, id: string, input: UpdatePlayerDto) {
    const existing = await this.prisma.player.findUnique({ where: { id } });
    if (!existing) {
      throw new NotFoundException('Player not found');
    }

    if (!currentUser.teamIds.includes(existing.teamId)) {
      throw new NotFoundException('Player not found');
    }

    return this.prisma.player.update({
      where: { id },
      data: {
        primaryPosition: input.primaryPosition,
        secondaryPositions: input.secondaryPositions,
        jerseyNumber: input.jerseyNumber,
        fitnessStatus: input.fitnessStatus,
        squadStatus: input.squadStatus,
        availabilityStatus: input.availabilityStatus,
      },
    });
  }

  async remove(currentUser: JwtPayload, id: string) {
    const existing = await this.prisma.player.findUnique({ where: { id } });
    if (!existing || !currentUser.teamIds.includes(existing.teamId)) {
      throw new NotFoundException('Player not found');
    }

    await this.prisma.player.delete({ where: { id } });
    return { success: true };
  }

  async positionOverview(currentUser: JwtPayload, teamId?: string) {
    const targetTeamIds = teamId ? [teamId] : currentUser.teamIds;
    const players = await this.prisma.player.findMany({
      where: { teamId: { in: targetTeamIds } },
    });

    const byPosition: Record<string, number> = {};
    const byFitness: Record<string, number> = {};

    for (const player of players) {
      byPosition[player.primaryPosition] = (byPosition[player.primaryPosition] ?? 0) + 1;
      byFitness[player.fitnessStatus] = (byFitness[player.fitnessStatus] ?? 0) + 1;
    }

    return {
      players: players.length,
      byPosition,
      byFitness,
    };
  }
}
