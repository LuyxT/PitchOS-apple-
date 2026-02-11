import {
  BadRequestException,
  Injectable,
  Logger,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { PrismaService } from '../../prisma/prisma.service';
import { LoginDto } from './dto/login.dto';
import { AuthResponseDto } from './dto/auth-response.dto';
import { JwtPayload } from './dto/jwt-payload.dto';
import { compare, hash } from 'bcryptjs';
import { randomUUID } from 'crypto';
import { RoleType } from '@prisma/client';
import { RegisterDto } from './dto/register.dto';

@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly jwtService: JwtService,
    private readonly configService: ConfigService,
  ) { }

  async login(input: LoginDto): Promise<AuthResponseDto> {
    const user = await this.prisma.user.findUnique({
      where: { email: input.email.toLowerCase() },
      include: {
        organization: true,
        clubMemberships: true,
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

    const teamIds = user.clubMemberships
      .map((m) => m.teamId)
      .filter((id): id is string => !!id);
    const payload = this.toJwtPayload(
      user.id,
      user.organizationId ?? null,
      teamIds,
      user.roles.map((r) => r.role.type),
    );
    return this.issueTokens(user.id, payload, user);
  }

  async register(input: RegisterDto): Promise<AuthResponseDto> {
    const email = input.email.toLowerCase().trim();
    const inviteCode = input.inviteCode?.trim() || undefined;

    this.logger.log({ event: 'auth.register.attempt', email, role: input.role, inviteCode: inviteCode ?? null });

    try {
      if (input.password !== input.passwordConfirmation) {
        this.logger.warn({ event: 'auth.register.validation', email, reason: 'password_mismatch' });
        throw new BadRequestException('Passwords do not match');
      }

      if (inviteCode) {
        const organization = await this.prisma.organization.findFirst({
          where: { inviteCode },
        });
        if (!organization) {
          this.logger.warn({ event: 'auth.register.validation', email, reason: 'invalid_invite' });
          throw new BadRequestException('Invite code not found');
        }
      }

      const existing = await this.prisma.user.findUnique({ where: { email } });
      if (existing) {
        this.logger.warn({ event: 'auth.register.validation', email, reason: 'email_in_use' });
        throw new BadRequestException('Email already in use');
      }

      const passwordHash = await hash(input.password, 10);

      const user = await this.prisma.user.create({
        data: {
          email,
          passwordHash,
          role: input.role,
          firstName: '',
          lastName: '',
          active: true,
          onboardingState: { create: {} },
        },
      });

      const payload = this.toJwtPayload(user.id, null, [], []);
      return this.issueTokens(user.id, payload, user);
    } catch (error) {
      if (error instanceof BadRequestException) {
        throw error;
      }
      this.logger.error({ event: 'auth.register.failure', email, reason: 'unexpected_error' }, error as Error);
      throw new BadRequestException('Unable to create account');
    }
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

  async logout(userId: string, refreshToken?: string): Promise<void> {
    if (!refreshToken) {
      await this.prisma.refreshToken.updateMany({
        where: { userId, revokedAt: null },
        data: { revokedAt: new Date() },
      });
      return;
    }

    const tokens = await this.prisma.refreshToken.findMany({
      where: { userId, revokedAt: null, expiresAt: { gt: new Date() } },
    });
    for (const token of tokens) {
      if (await compare(refreshToken, token.tokenHash)) {
        await this.prisma.refreshToken.update({
          where: { id: token.id },
          data: { revokedAt: new Date() },
        });
        break;
      }
    }
  }

  private async issueTokens(userId: string, payload: JwtPayload, user?: { id: string; email: string; organizationId?: string | null; createdAt: Date }): Promise<AuthResponseDto> {
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
      user: user
        ? {
          id: user.id,
          email: user.email,
          organizationId: user.organizationId ?? null,
          createdAt: user.createdAt,
        }
        : undefined,
    };
  }

  private toJwtPayload(
    sub: string,
    orgId: string | null,
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
