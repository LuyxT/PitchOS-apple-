import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { CreateTeamDto } from './dto/create-team.dto';

@Injectable()
export class TeamsService {
  constructor(private readonly prisma: PrismaService) {}

  async create(input: CreateTeamDto) {
    const club = await this.prisma.organization.findUnique({ where: { id: input.clubId } });
    if (!club) {
      throw new NotFoundException('Club not found');
    }

    const normalized = this.normalizeName(input.teamName);
    const existing = await this.prisma.team.findFirst({
      where: { organizationId: input.clubId, nameNormalized: normalized },
    });

    if (existing) {
      return existing;
    }

    return this.prisma.team.create({
      data: {
        organizationId: input.clubId,
        name: input.teamName.trim(),
        nameNormalized: normalized,
        league: input.league?.trim() || null,
      },
    });
  }

  private normalizeName(name: string) {
    return name
      .toLowerCase()
      .normalize('NFD')
      .replace(/\p{Diacritic}/gu, '')
      .replace(/[^a-z0-9]+/g, ' ')
      .trim();
  }
}
