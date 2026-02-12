import { Injectable, NotFoundException } from '@nestjs/common';
import { ERROR_CODES } from '../common/constants/error-codes';
import { PrismaService } from '../prisma/prisma.service';
import { CreatePlayerDto } from './dto/create-player.dto';

@Injectable()
export class PlayersService {
  constructor(private readonly prisma: PrismaService) {}

  async createPlayer(dto: CreatePlayerDto): Promise<Record<string, unknown>> {
    const team = await this.prisma.team.findUnique({
      where: { id: dto.teamId },
    });

    if (!team) {
      throw new NotFoundException({
        code: ERROR_CODES.notFound,
        message: 'Team not found.',
      });
    }

    const player = await this.prisma.player.create({
      data: {
        teamId: dto.teamId,
        firstName: dto.firstName.trim(),
        lastName: dto.lastName.trim(),
        position: dto.position?.trim() || null,
      },
    });

    return this.mapPlayer(player);
  }

  async listPlayers(teamId: string): Promise<Array<Record<string, unknown>>> {
    const players = await this.prisma.player.findMany({
      where: { teamId },
      orderBy: { createdAt: 'asc' },
    });

    return players.map((player) => this.mapPlayer(player));
  }

  private mapPlayer(player: {
    id: string;
    teamId: string;
    firstName: string;
    lastName: string;
    position: string | null;
    createdAt: Date;
    updatedAt: Date;
  }) {
    return {
      id: player.id,
      teamId: player.teamId,
      firstName: player.firstName,
      lastName: player.lastName,
      position: player.position,
      createdAt: player.createdAt,
      updatedAt: player.updatedAt,
    };
  }
}
