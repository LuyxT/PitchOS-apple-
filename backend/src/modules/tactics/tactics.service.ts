import { Injectable, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { JwtPayload } from '../auth/dto/jwt-payload.dto';
import { CreateTacticsBoardDto, UpdateTacticsBoardDto } from './dto/tactics-board.dto';

@Injectable()
export class TacticsService {
  constructor(private readonly prisma: PrismaService) {}

  async list(currentUser: JwtPayload, teamId?: string) {
    return this.prisma.tacticsBoard.findMany({
      where: {
        teamId: teamId ? teamId : { in: currentUser.teamIds },
      },
      orderBy: { updatedAt: 'desc' },
    });
  }

  async get(currentUser: JwtPayload, id: string) {
    const board = await this.prisma.tacticsBoard.findUnique({ where: { id } });
    if (!board || !currentUser.teamIds.includes(board.teamId)) {
      throw new NotFoundException('Tactics board not found');
    }
    return board;
  }

  async create(currentUser: JwtPayload, input: CreateTacticsBoardDto) {
    return this.prisma.tacticsBoard.create({
      data: {
        teamId: input.teamId,
        name: input.name,
        scenarioName: input.scenarioName,
        placements: input.placements as Prisma.InputJsonValue,
        benchPlayerIds: input.benchPlayerIds ?? [],
        excludedPlayerIds: input.excludedPlayerIds ?? [],
        opponentMode: input.opponentMode,
        opponentMarkers: input.opponentMarkers as Prisma.InputJsonValue | undefined,
        drawings: input.drawings as Prisma.InputJsonValue | undefined,
        cloudFileId: input.cloudFileId,
        createdBy: currentUser.sub,
      },
    });
  }

  async update(currentUser: JwtPayload, id: string, input: UpdateTacticsBoardDto) {
    await this.get(currentUser, id);

    const current = await this.prisma.tacticsBoard.findUniqueOrThrow({ where: { id } });

    return this.prisma.tacticsBoard.update({
      where: { id },
      data: {
        name: input.name,
        scenarioName: input.scenarioName,
        placements: input.placements as Prisma.InputJsonValue | undefined,
        benchPlayerIds: input.benchPlayerIds,
        excludedPlayerIds: input.excludedPlayerIds,
        opponentMode: input.opponentMode,
        opponentMarkers: input.opponentMarkers as Prisma.InputJsonValue | undefined,
        drawings: input.drawings as Prisma.InputJsonValue | undefined,
        cloudFileId: input.cloudFileId,
        version: current.version + 1,
      },
    });
  }

  async remove(currentUser: JwtPayload, id: string) {
    await this.get(currentUser, id);
    await this.prisma.tacticsBoard.delete({ where: { id } });
    return { success: true };
  }
}
