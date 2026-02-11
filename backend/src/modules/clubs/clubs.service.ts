import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { CreateClubDto } from './dto/create-club.dto';
import { JoinClubDto } from './dto/join-club.dto';
import { MembershipRole, MembershipStatus } from '@prisma/client';
import { randomBytes } from 'crypto';

@Injectable()
export class ClubsService {
  constructor(private readonly prisma: PrismaService) {}

  async search(query: string, region?: string) {
    const trimmed = query.trim();
    if (trimmed.length < 2) {
      return [];
    }
    const normalized = this.normalizeName(trimmed);

    return this.prisma.organization.findMany({
      where: {
        nameNormalized: { contains: normalized },
        region: region ? region.trim() : undefined,
      },
      select: {
        id: true,
        name: true,
        city: true,
        postalCode: true,
        region: true,
      },
      take: 8,
    });
  }

  async create(userId: string, input: CreateClubDto) {
    const inviteCode = await this.generateInviteCode();
    const nameNormalized = this.normalizeName(input.name);

    return this.prisma.organization.create({
      data: {
        name: input.name.trim(),
        nameNormalized,
        region: input.region.trim(),
        city: input.city?.trim() || null,
        postalCode: input.postalCode?.trim() || null,
        verified: false,
        inviteCode,
        createdByUserId: userId,
      },
    });
  }

  async join(userId: string, input: JoinClubDto) {
    const club = await this.prisma.organization.findUnique({ where: { id: input.clubId } });
    if (!club) {
      throw new NotFoundException('Club not found');
    }

    const role = this.mapRole(input.role);
    const requiresTeam = role !== MembershipRole.VORSTAND;
    if (requiresTeam && !input.teamId) {
      throw new BadRequestException('Team is required for this role');
    }

    const status = role === MembershipRole.VORSTAND ? MembershipStatus.ACTIVE : MembershipStatus.PENDING;

    await this.prisma.membership.create({
      data: {
        userId,
        organizationId: input.clubId,
        teamId: input.teamId ?? null,
        role,
        status,
      },
    }).catch(() => undefined);

    await this.prisma.user.update({
      where: { id: userId },
      data: {
        organizationId: input.clubId,
        primaryTeamId: input.teamId ?? undefined,
      },
    });

    await this.prisma.onboardingState.upsert({
      where: { userId },
      update: { lastStep: 'club' },
      create: { userId, lastStep: 'club' },
    });

    return {
      clubId: input.clubId,
      teamId: input.teamId ?? null,
      membershipStatus: status === MembershipStatus.ACTIVE ? 'active' : 'pending',
    };
  }

  private mapRole(raw: string): MembershipRole {
    switch (raw) {
      case 'trainer':
        return MembershipRole.TRAINER;
      case 'co_trainer':
        return MembershipRole.CO_TRAINER;
      case 'physio':
        return MembershipRole.PHYSIO;
      case 'vorstand':
        return MembershipRole.VORSTAND;
      case 'player':
        return MembershipRole.TRAINER;
      default:
        return MembershipRole.TRAINER;
    }
  }

  private normalizeName(name: string) {
    return name
      .toLowerCase()
      .normalize('NFD')
      .replace(/\p{Diacritic}/gu, '')
      .replace(/[^a-z0-9]+/g, ' ')
      .trim();
  }

  private async generateInviteCode(): Promise<string> {
    while (true) {
      const code = randomBytes(4).toString('hex').toUpperCase();
      const existing = await this.prisma.organization.findFirst({ where: { inviteCode: code } });
      if (!existing) {
        return code;
      }
    }
  }
}
