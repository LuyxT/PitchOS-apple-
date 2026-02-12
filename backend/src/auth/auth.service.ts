import {
  BadRequestException,
  Injectable,
  NotFoundException,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { InviteCodeTargetType, User, UserRole } from '@prisma/client';
import * as bcrypt from 'bcryptjs';
import { ERROR_CODES } from '../common/constants/error-codes';
import { parseDurationToMs } from '../common/utils/date.util';
import { normalizeInviteCode } from '../common/utils/normalization.util';
import { resolveOnboardingStatus } from '../common/utils/onboarding.util';
import { getEnv } from '../config/env';
import { PrismaService } from '../prisma/prisma.service';
import { LoginDto } from './dto/login.dto';
import { LogoutDto } from './dto/logout.dto';
import { RefreshDto } from './dto/refresh.dto';
import { RegisterDto } from './dto/register.dto';

interface AccessTokenPayload {
  sub: string;
  email: string;
  role: UserRole;
}

interface RefreshTokenPayload {
  sub: string;
  type: 'refresh';
}

interface UserProfile {
  id: string;
  email: string;
  role: UserRole;
  firstName: string | null;
  lastName: string | null;
  clubId: string | null;
  teamId: string | null;
  createdAt: Date;
  updatedAt: Date;
}

interface AuthTokens {
  tokenType: 'Bearer';
  accessToken: string;
  refreshToken: string;
  accessTokenExpiresIn: string;
  refreshTokenExpiresIn: string;
}

@Injectable()
export class AuthService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly jwtService: JwtService,
  ) {}

  async register(dto: RegisterDto): Promise<Record<string, unknown>> {
    const email = dto.email.trim().toLowerCase();

    const existing = await this.prisma.user.findUnique({ where: { email } });
    if (existing) {
      throw new BadRequestException({
        code: ERROR_CODES.conflict,
        message: 'Email already registered.',
      });
    }

    const inviteResolution = dto.inviteCode
      ? await this.resolveInviteCode(dto.inviteCode)
      : { clubId: null, teamId: null, inviteApplied: false, inviteCode: null };

    const passwordHash = await bcrypt.hash(dto.password, 10);

    const user = await this.prisma.user.create({
      data: {
        email,
        passwordHash,
        role: dto.role ?? UserRole.TRAINER,
        firstName: dto.firstName?.trim() || null,
        lastName: dto.lastName?.trim() || null,
        clubId: inviteResolution.clubId,
        teamId: inviteResolution.teamId,
      },
    });

    const tokens = await this.issueTokens(user);
    const onboarding = resolveOnboardingStatus(user);
    const authPayload = this.buildAuthPayload(user, tokens, onboarding);

    return {
      ...authPayload,
      inviteApplied: inviteResolution.inviteApplied,
      inviteCode: inviteResolution.inviteCode,
    };
  }

  async login(dto: LoginDto): Promise<Record<string, unknown>> {
    const email = dto.email.trim().toLowerCase();
    const user = await this.prisma.user.findUnique({ where: { email } });

    if (!user) {
      throw new UnauthorizedException({
        code: ERROR_CODES.unauthorized,
        message: 'Invalid email or password.',
      });
    }

    const passwordMatches = await bcrypt.compare(
      dto.password,
      user.passwordHash,
    );

    if (!passwordMatches) {
      throw new UnauthorizedException({
        code: ERROR_CODES.unauthorized,
        message: 'Invalid email or password.',
      });
    }

    const tokens = await this.issueTokens(user);
    const onboarding = resolveOnboardingStatus(user);

    return this.buildAuthPayload(user, tokens, onboarding);
  }

  async refresh(dto: RefreshDto): Promise<Record<string, unknown>> {
    let payload: RefreshTokenPayload;

    try {
      payload = await this.jwtService.verifyAsync<RefreshTokenPayload>(
        dto.refreshToken,
        {
          secret: getEnv().JWT_REFRESH_SECRET,
        },
      );
    } catch {
      throw new UnauthorizedException({
        code: ERROR_CODES.unauthorized,
        message: 'Refresh token is invalid or expired.',
      });
    }

    if (payload.type !== 'refresh') {
      throw new UnauthorizedException({
        code: ERROR_CODES.unauthorized,
        message: 'Refresh token type is invalid.',
      });
    }

    const user = await this.prisma.user.findUnique({
      where: { id: payload.sub },
    });

    if (!user) {
      throw new UnauthorizedException({
        code: ERROR_CODES.unauthorized,
        message: 'User for refresh token not found.',
      });
    }

    const tokenRecord = await this.findRefreshTokenRecord(
      user.id,
      dto.refreshToken,
    );

    if (!tokenRecord) {
      throw new UnauthorizedException({
        code: ERROR_CODES.unauthorized,
        message: 'Refresh token has been revoked.',
      });
    }

    await this.prisma.refreshToken.update({
      where: { id: tokenRecord.id },
      data: { revokedAt: new Date() },
    });

    const tokens = await this.issueTokens(user);
    const onboarding = resolveOnboardingStatus(user);

    return this.buildAuthPayload(user, tokens, onboarding);
  }

  async logout(
    userId: string,
    dto: LogoutDto,
  ): Promise<Record<string, unknown>> {
    if (dto.refreshToken) {
      const tokenRecord = await this.findRefreshTokenRecord(
        userId,
        dto.refreshToken,
      );

      if (!tokenRecord) {
        return { loggedOut: true, revoked: 0 };
      }

      await this.prisma.refreshToken.update({
        where: { id: tokenRecord.id },
        data: { revokedAt: new Date() },
      });

      return { loggedOut: true, revoked: 1 };
    }

    const result = await this.prisma.refreshToken.updateMany({
      where: {
        userId,
        revokedAt: null,
      },
      data: {
        revokedAt: new Date(),
      },
    });

    return { loggedOut: true, revoked: result.count };
  }

  async me(userId: string): Promise<Record<string, unknown>> {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });

    if (!user) {
      throw new NotFoundException({
        code: ERROR_CODES.notFound,
        message: 'User not found.',
      });
    }

    const onboarding = resolveOnboardingStatus(user);

    return {
      user: this.toUserProfile(user),
      onboardingRequired: onboarding.onboardingRequired,
      nextStep: onboarding.nextStep,
    };
  }

  private async issueTokens(user: User): Promise<AuthTokens> {
    const env = getEnv();

    const accessPayload: AccessTokenPayload = {
      sub: user.id,
      email: user.email,
      role: user.role,
    };

    const refreshPayload: RefreshTokenPayload = {
      sub: user.id,
      type: 'refresh',
    };

    const accessToken = await this.jwtService.signAsync(accessPayload, {
      secret: env.JWT_ACCESS_SECRET,
      expiresIn: env.JWT_ACCESS_TTL,
    });

    const refreshToken = await this.jwtService.signAsync(refreshPayload, {
      secret: env.JWT_REFRESH_SECRET,
      expiresIn: env.JWT_REFRESH_TTL,
    });

    const refreshTokenHash = await bcrypt.hash(refreshToken, 10);
    const refreshExpiresInMs = parseDurationToMs(
      env.JWT_REFRESH_TTL,
      30 * 24 * 60 * 60 * 1000,
    );

    await this.prisma.refreshToken.create({
      data: {
        userId: user.id,
        tokenHash: refreshTokenHash,
        expiresAt: new Date(Date.now() + refreshExpiresInMs),
      },
    });

    return {
      tokenType: 'Bearer',
      accessToken,
      refreshToken,
      accessTokenExpiresIn: env.JWT_ACCESS_TTL,
      refreshTokenExpiresIn: env.JWT_REFRESH_TTL,
    };
  }

  private buildAuthPayload(
    user: User,
    tokens: AuthTokens,
    onboarding: { onboardingRequired: boolean; nextStep: string },
  ) {
    return {
      user: this.toUserProfile(user),
      token: tokens.accessToken,
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
      expiresIn: tokens.accessTokenExpiresIn,
      refreshExpiresIn: tokens.refreshTokenExpiresIn,
      tokens,
      onboardingRequired: onboarding.onboardingRequired,
      nextStep: onboarding.nextStep,
    };
  }

  private async findRefreshTokenRecord(userId: string, refreshToken: string) {
    const candidates = await this.prisma.refreshToken.findMany({
      where: {
        userId,
        revokedAt: null,
        expiresAt: {
          gt: new Date(),
        },
      },
      orderBy: {
        createdAt: 'desc',
      },
    });

    for (const candidate of candidates) {
      const isMatch = await bcrypt.compare(refreshToken, candidate.tokenHash);
      if (isMatch) {
        return candidate;
      }
    }

    return null;
  }

  private async resolveInviteCode(inviteCode: string): Promise<{
    clubId: string | null;
    teamId: string | null;
    inviteApplied: boolean;
    inviteCode: string | null;
  }> {
    const normalizedCode = normalizeInviteCode(inviteCode);

    const invite = await this.prisma.inviteCode.findUnique({
      where: { code: normalizedCode },
      include: {
        team: true,
      },
    });

    if (!invite || !invite.isActive) {
      throw new BadRequestException({
        code: ERROR_CODES.badRequest,
        message: 'Invite code is invalid.',
      });
    }

    if (invite.expiresAt && invite.expiresAt.getTime() < Date.now()) {
      throw new BadRequestException({
        code: ERROR_CODES.badRequest,
        message: 'Invite code is expired.',
      });
    }

    if (invite.targetType === InviteCodeTargetType.CLUB) {
      if (!invite.clubId) {
        throw new BadRequestException({
          code: ERROR_CODES.badRequest,
          message: 'Invite code is misconfigured (club missing).',
        });
      }

      return {
        clubId: invite.clubId,
        teamId: null,
        inviteApplied: true,
        inviteCode: invite.code,
      };
    }

    if (!invite.teamId || !invite.team) {
      throw new BadRequestException({
        code: ERROR_CODES.badRequest,
        message: 'Invite code is misconfigured (team missing).',
      });
    }

    return {
      clubId: invite.team.clubId,
      teamId: invite.teamId,
      inviteApplied: true,
      inviteCode: invite.code,
    };
  }

  private toUserProfile(user: User): UserProfile {
    return {
      id: user.id,
      email: user.email,
      role: user.role,
      firstName: user.firstName,
      lastName: user.lastName,
      clubId: user.clubId,
      teamId: user.teamId,
      createdAt: user.createdAt,
      updatedAt: user.updatedAt,
    };
  }
}
