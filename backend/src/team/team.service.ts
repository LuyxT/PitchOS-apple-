import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { ERROR_CODES } from '../common/constants/error-codes';
import { normalizeForMatch } from '../common/utils/normalization.util';
import { resolveOnboardingStatus } from '../common/utils/onboarding.util';
import { PrismaService } from '../prisma/prisma.service';
import { CreateTeamDto } from './dto/create-team.dto';

@Injectable()
export class TeamService {
  constructor(private readonly prisma: PrismaService) {}

  async createOrAttachTeam(
    userId: string,
    dto: CreateTeamDto,
  ): Promise<Record<string, unknown>> {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });

    if (!user) {
      throw new NotFoundException({
        code: ERROR_CODES.notFound,
        message: 'User not found.',
      });
    }

    const clubId = dto.clubId ?? user.clubId;

    if (!clubId) {
      throw new BadRequestException({
        code: ERROR_CODES.badRequest,
        message: 'Club is required before creating or joining a team.',
      });
    }

    const club = await this.prisma.club.findUnique({ where: { id: clubId } });

    if (!club) {
      throw new NotFoundException({
        code: ERROR_CODES.notFound,
        message: 'Club not found.',
      });
    }

    const normalizedName = normalizeForMatch(dto.name);
    const normalizedAgeGroup = normalizeForMatch(dto.ageGroup);
    const normalizedLeague = normalizeForMatch(dto.league);

    const existingTeam = await this.prisma.team.findUnique({
      where: {
        team_unique_normalized: {
          clubId,
          normalizedName,
          normalizedAgeGroup,
          normalizedLeague,
        },
      },
    });

    if (existingTeam) {
      const updatedUser = await this.prisma.user.update({
        where: { id: user.id },
        data: {
          clubId,
          teamId: existingTeam.id,
        },
      });

      const onboarding = resolveOnboardingStatus(updatedUser);

      return {
        teamExists: true,
        message: 'Team already exists. You were attached to the existing team.',
        team: this.mapTeam(existingTeam),
        onboardingRequired: onboarding.onboardingRequired,
        nextStep: onboarding.nextStep,
      };
    }

    try {
      const createdTeam = await this.prisma.team.create({
        data: {
          clubId,
          name: dto.name.trim(),
          ageGroup: dto.ageGroup.trim(),
          league: dto.league.trim(),
          normalizedName,
          normalizedAgeGroup,
          normalizedLeague,
        },
      });

      const updatedUser = await this.prisma.user.update({
        where: { id: user.id },
        data: {
          clubId,
          teamId: createdTeam.id,
        },
      });

      const onboarding = resolveOnboardingStatus(updatedUser);

      return {
        teamExists: false,
        message: 'Team created successfully.',
        team: this.mapTeam(createdTeam),
        onboardingRequired: onboarding.onboardingRequired,
        nextStep: onboarding.nextStep,
      };
    } catch (error) {
      if (
        error instanceof Prisma.PrismaClientKnownRequestError &&
        error.code === 'P2002'
      ) {
        const merged = await this.prisma.team.findUnique({
          where: {
            team_unique_normalized: {
              clubId,
              normalizedName,
              normalizedAgeGroup,
              normalizedLeague,
            },
          },
        });

        if (merged) {
          const updatedUser = await this.prisma.user.update({
            where: { id: user.id },
            data: {
              clubId,
              teamId: merged.id,
            },
          });

          const onboarding = resolveOnboardingStatus(updatedUser);

          return {
            teamExists: true,
            message:
              'Team already exists. You were attached to the existing team.',
            team: this.mapTeam(merged),
            onboardingRequired: onboarding.onboardingRequired,
            nextStep: onboarding.nextStep,
          };
        }
      }

      throw error;
    }
  }

  async listTeams(
    userId: string,
    clubId?: string,
  ): Promise<Array<Record<string, unknown>>> {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });

    if (!user) {
      throw new NotFoundException({
        code: ERROR_CODES.notFound,
        message: 'User not found.',
      });
    }

    const resolvedClubId = clubId ?? user.clubId;

    if (!resolvedClubId) {
      return [];
    }

    const teams = await this.prisma.team.findMany({
      where: { clubId: resolvedClubId },
      orderBy: { createdAt: 'asc' },
    });

    return teams.map((team) => this.mapTeam(team));
  }

  private mapTeam(team: {
    id: string;
    clubId: string;
    name: string;
    ageGroup: string;
    league: string;
    createdAt: Date;
    updatedAt: Date;
  }) {
    return {
      id: team.id,
      clubId: team.clubId,
      name: team.name,
      ageGroup: team.ageGroup,
      league: team.league,
      createdAt: team.createdAt,
      updatedAt: team.updatedAt,
    };
  }
}
