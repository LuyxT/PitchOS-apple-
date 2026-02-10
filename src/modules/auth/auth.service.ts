import {
  BadRequestException,
  ConflictException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { PrismaService } from '../../prisma/prisma.service';
import { LoginDto } from './dto/login.dto';
import { AuthResponseDto } from './dto/auth-response.dto';
import { JwtPayload } from './dto/jwt-payload.dto';
import { RegisterDto } from './dto/register.dto';
import { compare, hash } from 'bcryptjs';
import { randomUUID } from 'crypto';
import { RoleType } from '@prisma/client';

@Injectable()
export class AuthService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly jwtService: JwtService,
    private readonly configService: ConfigService,
  ) {}

  async register(input: RegisterDto): Promise<AuthResponseDto> {
    const email = input.email.toLowerCase();
    const existing = await this.prisma.user.findUnique({ where: { email } });
    if (existing) {
      throw new ConflictException('Email already in use');
    }

    const organization = await this.prisma.organization.findUnique({
      where: { id: input.organizationId },
      include: { teams: { select: { id: true } } },
    });
    if (!organization) {
      throw new BadRequestException('Organization not found');
    }

    if (input.teamId && !organization.teams.some((team) => team.id === input.teamId)) {
      throw new BadRequestException('Team does not belong to organization');
    }

    const passwordHash = await hash(input.password, 10);
    const roleType = input.roleType ?? RoleType.PLAYER;

    const role = await this.prisma.role.upsert({
      where: {
        organizationId_type: {
          organizationId: organization.id,
          type: roleType,
        },
      },
      create: {
        organizationId: organization.id,
        name: roleType,
        type: roleType,
        permissions: [],
      },
      update: {},
    });

    const user = await this.prisma.$transaction(async (tx) => {
      const created = await tx.user.create({
        data: {
          organizationId: organization.id,
          email,
          passwordHash,
          firstName: input.firstName,
          lastName: input.lastName,
          phone: input.phone,
          primaryTeamId: input.teamId,
          profile: { create: {} },
        },
      });

      await tx.userRole.create({
        data: {
          userId: created.id,
          roleId: role.id,
        },
      });

      if (input.teamId) {
        await tx.teamMembership.upsert({
          where: {
            teamId_userId: {
              teamId: input.teamId,
              userId: created.id,
            },
          },
          create: {
            teamId: input.teamId,
            userId: created.id,
          },
          update: {},
        });
      }

      return tx.user.findUniqueOrThrow({
        where: { id: created.id },
        include: {
          memberships: true,
          roles: { include: { role: true } },
        },
      });
    });

    const payload = this.toJwtPayload(
      user.id,
      user.organizationId,
      user.memberships.map((membership) => membership.teamId),
      user.roles.map((entry) => entry.role.type),
    );

    return this.issueTokens(user.id, payload);
  }

  async login(input: LoginDto): Promise<AuthResponseDto> {
    const user = await this.prisma.user.findUnique({
      where: { email: input.email.toLowerCase() },
      include: {
        organization: true,
        memberships: true,
        roles: { include: { role: true } },
      },
    });

    if (!user || !(await compare(input.password, user.passwordHash))) {
      throw new UnauthorizedException('Invalid credentials');
    }

    if (!user.active) {
      throw new UnauthorizedException('User is inactive');
    }

    const payload = this.toJwtPayload(user.id, user.organizationId, user.memberships.map((m) => m.teamId), user.roles.map((r) => r.role.type));
    return this.issueTokens(user.id, payload);
  }

  async refresh(refreshToken: string): Promise<AuthResponseDto> {
    const payload = this.jwtService.verify<JwtPayload>(refreshToken, {
      secret: this.configService.getOrThrow<string>('JWT_REFRESH_SECRET'),
    });

    const tokens = await this.prisma.refreshToken.findMany({
      where: {
        userId: payload.sub,
        revokedAt: null,
        expiresAt: { gt: new Date() },
      },
    });

    let match = false;
    for (const token of tokens) {
      if (await compare(refreshToken, token.tokenHash)) {
        match = true;
        await this.prisma.refreshToken.update({
          where: { id: token.id },
          data: { revokedAt: new Date() },
        });
        break;
      }
    }

    if (!match) {
      throw new UnauthorizedException('Invalid refresh token');
    }

    return this.issueTokens(payload.sub, payload);
  }

  async logout(userId: string): Promise<void> {
    await this.prisma.refreshToken.updateMany({
      where: { userId, revokedAt: null },
      data: { revokedAt: new Date() },
    });
  }

  private async issueTokens(userId: string, payload: JwtPayload): Promise<AuthResponseDto> {
    const accessExpiresIn = this.configService.getOrThrow<string>('JWT_ACCESS_EXPIRES_IN');
    const refreshExpiresIn = this.configService.getOrThrow<string>('JWT_REFRESH_EXPIRES_IN');

    const accessToken = await this.jwtService.signAsync(payload, {
      secret: this.configService.getOrThrow<string>('JWT_ACCESS_SECRET'),
      expiresIn: accessExpiresIn,
      jwtid: randomUUID(),
    });

    const refreshToken = await this.jwtService.signAsync(payload, {
      secret: this.configService.getOrThrow<string>('JWT_REFRESH_SECRET'),
      expiresIn: refreshExpiresIn,
      jwtid: randomUUID(),
    });

    const refreshHash = await hash(refreshToken, 10);
    const expiresAt = this.computeExpiryDate(refreshExpiresIn);

    await this.prisma.refreshToken.create({
      data: {
        userId,
        tokenHash: refreshHash,
        expiresAt,
      },
    });

    return {
      accessToken,
      refreshToken,
      expiresIn: accessExpiresIn,
      tokenType: 'Bearer',
    };
  }

  private toJwtPayload(
    sub: string,
    orgId: string,
    teamIds: string[],
    roles: RoleType[],
  ): JwtPayload {
    return {
      sub,
      orgId,
      teamIds: Array.from(new Set(teamIds)),
      roles: Array.from(new Set(roles)),
    };
  }

  private computeExpiryDate(interval: string): Date {
    const now = new Date();
    if (interval.endsWith('d')) {
      const days = Number(interval.replace('d', ''));
      now.setDate(now.getDate() + days);
      return now;
    }
    if (interval.endsWith('h')) {
      const hours = Number(interval.replace('h', ''));
      now.setHours(now.getHours() + hours);
      return now;
    }
    if (interval.endsWith('m')) {
      const minutes = Number(interval.replace('m', ''));
      now.setMinutes(now.getMinutes() + minutes);
      return now;
    }
    now.setDate(now.getDate() + 30);
    return now;
  }
}
