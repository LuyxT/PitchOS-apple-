import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JoinCodeType, MembershipStatus, RoleType } from '@prisma/client';
import { compare, hash } from 'bcryptjs';
import { randomUUID } from 'crypto';
import jwt from 'jsonwebtoken';
import { AppError } from '../../common/filters/app-error';
import { compareJoinCode } from '../../common/utils/join-code';
import { normalizeEmail } from '../../common/utils/normalize';
import { PrismaService } from '../../prisma/prisma.service';
import { LoginDto } from './dto/login.dto';
import { RegisterDto } from './dto/register.dto';

interface AuthTokens {
  accessToken: string;
  refreshToken: string;
}

@Injectable()
export class AuthService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly configService: ConfigService,
  ) {}

  async register(input: RegisterDto) {
    const email = normalizeEmail(input.email);

    if (input.password !== input.passwordConfirmation) {
      throw new AppError('passwordMismatch', 'Password confirmation does not match', null, 400);
    }

    const existing = await this.prisma.user.findUnique({ where: { email } });
    if (existing) {
      throw new AppError('emailInUse', 'Email is already registered', null, 409);
    }

    const passwordHash = await hash(input.password, 10);

    const created = await this.prisma.user.create({
      data: {
        email,
        passwordHash,
      },
    });

    if (input.inviteCode?.trim()) {
      await this.attachInviteMembership(created.id, input.role, input.inviteCode.trim());
    }

    const user = await this.prisma.user.findUnique({
      where: { id: created.id },
      include: { memberships: true },
    });

    if (!user) {
      throw new AppError('userCreationFailed', 'User could not be created', null, 500);
    }

    const tokens = await this.issueTokens(user.id, user.email);

    return {
      token: tokens.accessToken,
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
      user: {
        id: user.id,
        email: user.email,
        role: user.memberships[0]?.role ?? input.role,
        clubId: user.memberships[0]?.clubId ?? null,
      },
    };
  }

  async login(input: LoginDto) {
    const email = normalizeEmail(input.email);
    const user = await this.prisma.user.findUnique({
      where: { email },
      include: { memberships: true },
    });

    if (!user) {
      throw new AppError('invalidCredentials', 'Invalid email or password', null, 401);
    }

    const valid = await compare(input.password, user.passwordHash);
    if (!valid) {
      throw new AppError('invalidCredentials', 'Invalid email or password', null, 401);
    }

    const tokens = await this.issueTokens(user.id, user.email);

    return {
      token: tokens.accessToken,
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
      user: {
        id: user.id,
        email: user.email,
        role: user.memberships[0]?.role ?? null,
        clubId: user.memberships[0]?.clubId ?? null,
      },
    };
  }

  async refresh(refreshToken: string) {
    const payload = this.verifyRefreshToken(refreshToken);

    const storedTokens = await this.prisma.refreshToken.findMany({
      where: {
        userId: payload.sub,
        revokedAt: null,
        expiresAt: { gt: new Date() },
      },
    });

    const matched = await this.findMatchingRefreshToken(
      storedTokens.map((token) => ({ id: token.id, hash: token.tokenHash })),
      refreshToken,
    );

    if (!matched) {
      throw new AppError('invalidRefreshToken', 'Refresh token is invalid', null, 401);
    }

    await this.prisma.refreshToken.update({
      where: { id: matched.id },
      data: { revokedAt: new Date() },
    });

    const user = await this.prisma.user.findUnique({
      where: { id: payload.sub },
      include: { memberships: true },
    });

    if (!user) {
      throw new AppError('userNotFound', 'User not found', null, 404);
    }

    const tokens = await this.issueTokens(user.id, user.email);

    return {
      token: tokens.accessToken,
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
      user: {
        id: user.id,
        email: user.email,
        role: user.memberships[0]?.role ?? null,
        clubId: user.memberships[0]?.clubId ?? null,
      },
    };
  }

  async logout(userId: string, refreshToken?: string) {
    if (!refreshToken) {
      await this.prisma.refreshToken.updateMany({
        where: { userId, revokedAt: null },
        data: { revokedAt: new Date() },
      });
      return { loggedOut: true };
    }

    const tokenRows = await this.prisma.refreshToken.findMany({
      where: { userId, revokedAt: null, expiresAt: { gt: new Date() } },
    });

    const matched = await this.findMatchingRefreshToken(
      tokenRows.map((row) => ({ id: row.id, hash: row.tokenHash })),
      refreshToken,
    );

    if (matched) {
      await this.prisma.refreshToken.update({
        where: { id: matched.id },
        data: { revokedAt: new Date() },
      });
    }

    return { loggedOut: true };
  }

  async me(userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      include: {
        memberships: {
          include: {
            club: {
              select: { id: true, name: true, region: true, city: true },
            },
            team: {
              select: { id: true, name: true, season: true },
            },
          },
        },
      },
    });

    if (!user) {
      throw new AppError('userNotFound', 'User not found', null, 404);
    }

    const primaryMembership = user.memberships[0] ?? null;

    return {
      id: user.id,
      email: user.email,
      clubId: primaryMembership?.clubId ?? null,
      memberships: user.memberships,
      role: primaryMembership?.role ?? null,
      onboardingRequired: user.memberships.length === 0,
    };
  }

  private async attachInviteMembership(userId: string, role: RoleType, inviteCode: string): Promise<void> {
    const normalizedCode = inviteCode.toUpperCase();

    const club = await this.prisma.club.findFirst({
      where: { inviteCode: normalizedCode },
    });

    if (club) {
      await this.prisma.membership.create({
        data: {
          userId,
          clubId: club.id,
          role,
          status: MembershipStatus.ACTIVE,
        },
      });
      return;
    }

    const joinCodes = await this.prisma.joinCode.findMany({
      where: { isActive: true },
      include: { team: true },
    });

    const pepper = this.configService.get<string>('JOIN_CODE_PEPPER') || 'replace_me_join_code_pepper';
    const matched = joinCodes.find((item) => compareJoinCode(normalizedCode, item.codeHash, pepper));

    if (!matched) {
      throw new AppError('invalidInviteCode', 'Invite code is invalid', null, 400);
    }

    const mappedRole = matched.type === JoinCodeType.PLAYER ? RoleType.PLAYER : role;

    await this.prisma.membership.create({
      data: {
        userId,
        clubId: matched.team.clubId,
        teamId: matched.teamId,
        role: mappedRole,
        status: MembershipStatus.ACTIVE,
      },
    });
  }

  private async issueTokens(userId: string, email: string): Promise<AuthTokens> {
    const accessToken = this.signAccessToken(userId, email);
    const refreshToken = this.signRefreshToken(userId, email);

    const tokenHash = await hash(`${refreshToken}::${this.refreshPepper()}`, 10);

    await this.prisma.refreshToken.create({
      data: {
        userId,
        tokenHash,
        expiresAt: this.computeExpiryDate(this.configService.get<string>('JWT_REFRESH_EXPIRES_IN') || '30d'),
      },
    });

    return { accessToken, refreshToken };
  }

  private signAccessToken(userId: string, email: string): string {
    return jwt.sign(
      { sub: userId, email, type: 'access' },
      this.configService.get<string>('JWT_ACCESS_SECRET') || 'replace_me_access',
      {
        expiresIn: this.configService.get<string>('JWT_ACCESS_EXPIRES_IN') || '15m',
        jwtid: randomUUID(),
      },
    );
  }

  private signRefreshToken(userId: string, email: string): string {
    return jwt.sign(
      { sub: userId, email, type: 'refresh' },
      this.configService.get<string>('JWT_REFRESH_SECRET') || 'replace_me_refresh',
      {
        expiresIn: this.configService.get<string>('JWT_REFRESH_EXPIRES_IN') || '30d',
        jwtid: randomUUID(),
      },
    );
  }

  private verifyRefreshToken(token: string): { sub: string } {
    try {
      const payload = jwt.verify(
        token,
        this.configService.get<string>('JWT_REFRESH_SECRET') || 'replace_me_refresh',
      ) as { sub: string; type: string };

      if (payload.type !== 'refresh') {
        throw new Error('not-refresh');
      }

      return { sub: payload.sub };
    } catch {
      throw new AppError('invalidRefreshToken', 'Refresh token is invalid', null, 401);
    }
  }

  private refreshPepper(): string {
    return this.configService.get<string>('REFRESH_TOKEN_PEPPER') || 'replace_me_refresh_pepper';
  }

  private computeExpiryDate(interval: string): Date {
    const now = new Date();
    if (interval.endsWith('d')) {
      now.setDate(now.getDate() + Number(interval.slice(0, -1)));
      return now;
    }
    if (interval.endsWith('h')) {
      now.setHours(now.getHours() + Number(interval.slice(0, -1)));
      return now;
    }
    if (interval.endsWith('m')) {
      now.setMinutes(now.getMinutes() + Number(interval.slice(0, -1)));
      return now;
    }
    now.setDate(now.getDate() + 30);
    return now;
  }

  private async findMatchingRefreshToken(
    rows: Array<{ id: string; hash: string }>,
    refreshToken: string,
  ): Promise<{ id: string } | null> {
    for (const row of rows) {
      const valid = await compare(`${refreshToken}::${this.refreshPepper()}`, row.hash);
      if (valid) {
        return { id: row.id };
      }
    }
    return null;
  }
}
