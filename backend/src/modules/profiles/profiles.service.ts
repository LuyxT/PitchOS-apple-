import { ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { Prisma, RoleType } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { JwtPayload } from '../auth/dto/jwt-payload.dto';
import { UpdateProfileDto } from './dto/update-profile.dto';

@Injectable()
export class ProfilesService {
  constructor(private readonly prisma: PrismaService) { }

  async list(currentUser: JwtPayload) {
    if (!this.canReadAllProfiles(currentUser.roles)) {
      return this.getByUserId(currentUser, currentUser.sub);
    }

    return this.prisma.profile.findMany({
      where: { user: { organizationId: currentUser.orgId } },
      include: {
        user: {
          include: {
            roles: { include: { role: true } },
            memberships: true,
          },
        },
        playerProfile: true,
        trainerProfile: true,
        physioProfile: true,
        managerProfile: true,
        boardProfile: true,
      },
      orderBy: { updatedAt: 'desc' },
    });
  }

  async getByUserId(currentUser: JwtPayload, userId: string) {
    if (currentUser.sub != userId && !this.canReadAllProfiles(currentUser.roles)) {
      throw new ForbiddenException('Not allowed to read this profile');
    }

    const profile = await this.prisma.profile.findFirst({
      where: { userId, user: { organizationId: currentUser.orgId } },
      include: {
        user: {
          include: {
            roles: { include: { role: true } },
            memberships: true,
          },
        },
        playerProfile: true,
        trainerProfile: true,
        physioProfile: true,
        managerProfile: true,
        boardProfile: true,
      },
    });

    if (!profile) {
      throw new NotFoundException('Profile not found');
    }

    return profile;
  }

  async update(currentUser: JwtPayload, userId: string, input: UpdateProfileDto) {
    const target = await this.getByUserId(currentUser, userId);
    if (currentUser.sub !== userId && !this.canManageProfiles(currentUser.roles)) {
      throw new ForbiddenException('Not allowed to edit this profile');
    }

    const updated = await this.prisma.$transaction(async (tx) => {
      await tx.user.update({
        where: { id: userId },
        data: {
          firstName: input.firstName,
          lastName: input.lastName,
          phone: input.phone,
        },
      });

      const profile = await tx.profile.update({
        where: { id: target.id },
        data: {
          birthDate: input.birthDate ? new Date(input.birthDate) : undefined,
          clubMembership: input.clubMembership,
          activeStatus: input.activeStatus,
          notes: input.notes,
        },
      });

      if (input.playerGoals || input.playerBiography || input.playerPreferredRole) {
        await tx.playerProfile.upsert({
          where: { profileId: profile.id },
          create: {
            profileId: profile.id,
            goals: input.playerGoals ?? [],
            biography: input.playerBiography,
            preferredRole: input.playerPreferredRole,
          },
          update: {
            goals: input.playerGoals,
            biography: input.playerBiography,
            preferredRole: input.playerPreferredRole,
          },
        });
      }

      if (input.trainerLicenses || input.trainerEducation || input.trainerPhilosophy || input.trainerGoals || input.trainerCareerHistory) {
        await tx.trainerProfile.upsert({
          where: { profileId: profile.id },
          create: {
            profileId: profile.id,
            licenses: input.trainerLicenses ?? [],
            education: input.trainerEducation ?? [],
            philosophy: input.trainerPhilosophy,
            goals: input.trainerGoals ?? [],
            careerHistory: input.trainerCareerHistory,
            responsibilities: [],
          },
          update: {
            licenses: input.trainerLicenses,
            education: input.trainerEducation,
            philosophy: input.trainerPhilosophy,
            goals: input.trainerGoals,
            careerHistory: input.trainerCareerHistory,
          },
        });
      }

      if (input.physioQualifications) {
        await tx.physioProfile.upsert({
          where: { profileId: profile.id },
          create: {
            profileId: profile.id,
            qualifications: input.physioQualifications,
            specializations: [],
            assignedGroups: [],
          },
          update: {
            qualifications: input.physioQualifications,
          },
        });
      }

      if (input.managerResponsibilities) {
        await tx.managerProfile.upsert({
          where: { profileId: profile.id },
          create: {
            profileId: profile.id,
            responsibilities: input.managerResponsibilities,
          },
          update: {
            responsibilities: input.managerResponsibilities,
          },
        });
      }

      if (input.boardFunction || input.boardResponsibilities) {
        await tx.boardProfile.upsert({
          where: { profileId: profile.id },
          create: {
            profileId: profile.id,
            boardFunction: input.boardFunction,
            responsibilities: input.boardResponsibilities ?? [],
          },
          update: {
            boardFunction: input.boardFunction,
            responsibilities: input.boardResponsibilities,
          },
        });
      }

      await tx.profileVersion.create({
        data: {
          profileId: profile.id,
          changedBy: currentUser.sub,
          diff: input as Prisma.InputJsonValue,
        },
      });

      return tx.profile.findUniqueOrThrow({
        where: { id: profile.id },
        include: {
          user: {
            include: { roles: { include: { role: true } }, memberships: true },
          },
          playerProfile: true,
          trainerProfile: true,
          physioProfile: true,
          managerProfile: true,
          boardProfile: true,
        },
      });
    });

    return updated;
  }

  private canReadAllProfiles(roles: RoleType[]): boolean {
    const allowed: RoleType[] = [RoleType.ADMIN, RoleType.TRAINER, RoleType.CO_TRAINER, RoleType.TEAM_MANAGER];
    return roles.some((role) =>
      allowed.includes(role),
    );
  }

  private canManageProfiles(roles: RoleType[]): boolean {
    const allowed: RoleType[] = [RoleType.ADMIN, RoleType.TRAINER, RoleType.TEAM_MANAGER];
    return roles.some((role) =>
      allowed.includes(role),
    );
  }
}
