import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { JwtPayload } from '../auth/dto/jwt-payload.dto';
import {
  CreateInvitationDto,
  CreateRoleDto,
  CreateSeasonDto,
  UpdateInvitationDto,
  UpdateRoleDto,
  UpdateSeasonDto,
} from './dto/admin.dto';
import { randomUUID } from 'crypto';

@Injectable()
export class AdminService {
  constructor(private readonly prisma: PrismaService) {}

  async dashboard(currentUser: JwtPayload) {
    const [users, invitations, seasons, audit] = await Promise.all([
      this.prisma.user.count({ where: { organizationId: currentUser.orgId } }),
      this.prisma.invitation.count({ where: { organizationId: currentUser.orgId, status: 'OPEN' } }),
      this.prisma.season.findMany({ where: { organizationId: currentUser.orgId }, orderBy: { startsAt: 'desc' }, take: 5 }),
      this.prisma.auditLog.findMany({ where: { organizationId: currentUser.orgId }, orderBy: { createdAt: 'desc' }, take: 20 }),
    ]);

    return {
      users,
      openInvitations: invitations,
      seasons,
      latestAudit: audit,
    };
  }

  async roles(currentUser: JwtPayload) {
    return this.prisma.role.findMany({
      where: { organizationId: currentUser.orgId },
      orderBy: { type: 'asc' },
    });
  }

  async createRole(currentUser: JwtPayload, input: CreateRoleDto) {
    return this.prisma.role.create({
      data: {
        organizationId: currentUser.orgId,
        name: input.name,
        type: input.type,
        permissions: input.permissions,
      },
    });
  }

  async updateRole(currentUser: JwtPayload, id: string, input: UpdateRoleDto) {
    return this.prisma.role.update({
      where: { id },
      data: {
        name: input.name,
        permissions: input.permissions,
      },
    });
  }

  async invitations(currentUser: JwtPayload) {
    return this.prisma.invitation.findMany({
      where: { organizationId: currentUser.orgId },
      orderBy: { createdAt: 'desc' },
    });
  }

  async createInvitation(currentUser: JwtPayload, input: CreateInvitationDto) {
    return this.prisma.invitation.create({
      data: {
        organizationId: currentUser.orgId,
        email: input.email.toLowerCase(),
        roleType: input.roleType,
        teamId: input.teamId,
        inviteToken: randomUUID(),
        expiresAt: new Date(Date.now() + 1000 * 60 * 60 * 24 * 7),
        createdBy: currentUser.sub,
      },
    });
  }

  async updateInvitation(currentUser: JwtPayload, id: string, input: UpdateInvitationDto) {
    return this.prisma.invitation.update({
      where: { id },
      data: {
        status: input.status,
        acceptedAt: input.status === 'ACCEPTED' ? new Date() : undefined,
      },
    });
  }

  async seasons(currentUser: JwtPayload) {
    return this.prisma.season.findMany({
      where: { organizationId: currentUser.orgId },
      orderBy: { startsAt: 'desc' },
    });
  }

  async createSeason(currentUser: JwtPayload, input: CreateSeasonDto) {
    return this.prisma.season.create({
      data: {
        organizationId: currentUser.orgId,
        name: input.name,
        startsAt: new Date(input.startsAt),
        endsAt: new Date(input.endsAt),
      },
    });
  }

  async updateSeason(currentUser: JwtPayload, id: string, input: UpdateSeasonDto) {
    const season = await this.prisma.season.findUnique({ where: { id } });
    if (!season || season.organizationId !== currentUser.orgId) {
      throw new NotFoundException('Season not found');
    }

    if (input.isActive) {
      await this.prisma.season.updateMany({
        where: { organizationId: currentUser.orgId },
        data: { isActive: false },
      });
    }

    return this.prisma.season.update({
      where: { id },
      data: {
        isActive: input.isActive,
        isLocked: input.isLocked,
        isArchived: input.isArchived,
      },
    });
  }

  async auditLog(currentUser: JwtPayload, actorUserId?: string, area?: string) {
    return this.prisma.auditLog.findMany({
      where: {
        organizationId: currentUser.orgId,
        actorUserId,
        area,
      },
      orderBy: { createdAt: 'desc' },
      take: 200,
    });
  }
}
