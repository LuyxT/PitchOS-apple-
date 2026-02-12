import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { CreateUserDto } from './dto/create-user.dto';
import { UpdateUserDto } from './dto/update-user.dto';
import { hash } from 'bcryptjs';

@Injectable()
export class UsersService {
  constructor(private readonly prisma: PrismaService) {}

  async list(organizationId: string) {
    return this.prisma.user.findMany({
      where: { organizationId },
      include: {
        roles: { include: { role: true } },
        memberships: true,
        profile: true,
      },
      orderBy: { lastName: 'asc' },
    });
  }

  async get(organizationId: string, userId: string) {
    const user = await this.prisma.user.findFirst({
      where: { organizationId, id: userId },
      include: {
        roles: { include: { role: true } },
        memberships: true,
        profile: {
          include: {
            playerProfile: true,
            trainerProfile: true,
            physioProfile: true,
            managerProfile: true,
            boardProfile: true,
          },
        },
      },
    });

    if (!user) {
      throw new NotFoundException('User not found');
    }

    return user;
  }

  async create(organizationId: string, input: CreateUserDto) {
    const passwordHash = await hash(input.password, 10);

    return this.prisma.$transaction(async (tx) => {
      const user = await tx.user.create({
        data: {
          organizationId,
          email: input.email.toLowerCase(),
          passwordHash,
          firstName: input.firstName,
          lastName: input.lastName,
          phone: input.phone,
          primaryTeamId: input.primaryTeamId,
          profile: { create: {} },
        },
      });

      if (input.roleIds?.length) {
        await tx.userRole.createMany({
          data: input.roleIds.map((roleId) => ({ userId: user.id, roleId })),
          skipDuplicates: true,
        });
      }

      if (input.membershipTeamIds?.length) {
        await tx.teamMembership.createMany({
          data: input.membershipTeamIds.map((teamId) => ({ userId: user.id, teamId })),
          skipDuplicates: true,
        });
      }

      return tx.user.findUniqueOrThrow({
        where: { id: user.id },
        include: { roles: { include: { role: true } }, memberships: true },
      });
    });
  }

  async update(organizationId: string, userId: string, input: UpdateUserDto) {
    await this.get(organizationId, userId);

    return this.prisma.$transaction(async (tx) => {
      const user = await tx.user.update({
        where: { id: userId },
        data: {
          firstName: input.firstName,
          lastName: input.lastName,
          phone: input.phone,
          active: input.active,
          primaryTeamId: input.primaryTeamId,
        },
      });

      if (input.roleIds) {
        await tx.userRole.deleteMany({ where: { userId } });
        if (input.roleIds.length) {
          await tx.userRole.createMany({
            data: input.roleIds.map((roleId) => ({ userId, roleId })),
            skipDuplicates: true,
          });
        }
      }

      if (input.membershipTeamIds) {
        await tx.teamMembership.deleteMany({ where: { userId } });
        if (input.membershipTeamIds.length) {
          await tx.teamMembership.createMany({
            data: input.membershipTeamIds.map((teamId) => ({ userId, teamId })),
            skipDuplicates: true,
          });
        }
      }

      return tx.user.findUniqueOrThrow({
        where: { id: user.id },
        include: { roles: { include: { role: true } }, memberships: true },
      });
    });
  }

  async remove(organizationId: string, userId: string) {
    await this.get(organizationId, userId);
    await this.prisma.user.delete({ where: { id: userId } });
    return { success: true };
  }
}
