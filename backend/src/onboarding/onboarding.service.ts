import { BadRequestException, Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { ERROR_CODES } from '../common/constants/error-codes';
import { normalizeForMatch } from '../common/utils/normalization.util';
import { resolveOnboardingStatus } from '../common/utils/onboarding.util';
import { PrismaService } from '../prisma/prisma.service';
import { CreateClubDto } from './dto/create-club.dto';

@Injectable()
export class OnboardingService {
  constructor(private readonly prisma: PrismaService) {}

  async createClub(
    userId: string,
    dto: CreateClubDto,
  ): Promise<Record<string, unknown>> {
    const normalizedName = normalizeForMatch(dto.name);
    const normalizedCity = normalizeForMatch(dto.city);

    if (!normalizedName || !normalizedCity) {
      throw new BadRequestException({
        code: ERROR_CODES.validation,
        message: 'Club name and city are required.',
      });
    }

    const existingClub = await this.prisma.club.findUnique({
      where: {
        normalizedName_normalizedCity: {
          normalizedName,
          normalizedCity,
        },
      },
    });

    if (existingClub) {
      const user = await this.prisma.user.update({
        where: { id: userId },
        data: {
          clubId: existingClub.id,
          teamId: null,
        },
      });

      const onboarding = resolveOnboardingStatus(user);

      return {
        clubExists: true,
        message: 'Club already exists. You were attached to the existing club.',
        club: this.mapClub(existingClub),
        onboardingRequired: onboarding.onboardingRequired,
        nextStep: onboarding.nextStep,
      };
    }

    try {
      const createdClub = await this.prisma.club.create({
        data: {
          name: dto.name.trim(),
          city: dto.city.trim(),
          region: dto.region.trim(),
          normalizedName,
          normalizedCity,
        },
      });

      const user = await this.prisma.user.update({
        where: { id: userId },
        data: {
          clubId: createdClub.id,
          teamId: null,
        },
      });

      const onboarding = resolveOnboardingStatus(user);

      return {
        clubExists: false,
        message: 'Club created successfully.',
        club: this.mapClub(createdClub),
        onboardingRequired: onboarding.onboardingRequired,
        nextStep: onboarding.nextStep,
      };
    } catch (error) {
      if (
        error instanceof Prisma.PrismaClientKnownRequestError &&
        error.code === 'P2002'
      ) {
        const mergedClub = await this.prisma.club.findUnique({
          where: {
            normalizedName_normalizedCity: {
              normalizedName,
              normalizedCity,
            },
          },
        });

        if (mergedClub) {
          const user = await this.prisma.user.update({
            where: { id: userId },
            data: {
              clubId: mergedClub.id,
              teamId: null,
            },
          });

          const onboarding = resolveOnboardingStatus(user);

          return {
            clubExists: true,
            message:
              'Club already exists. You were attached to the existing club.',
            club: this.mapClub(mergedClub),
            onboardingRequired: onboarding.onboardingRequired,
            nextStep: onboarding.nextStep,
          };
        }
      }

      throw error;
    }
  }

  private mapClub(club: {
    id: string;
    name: string;
    city: string;
    region: string;
    createdAt: Date;
    updatedAt: Date;
  }) {
    return {
      id: club.id,
      name: club.name,
      city: club.city,
      region: club.region,
      createdAt: club.createdAt,
      updatedAt: club.updatedAt,
    };
  }
}
