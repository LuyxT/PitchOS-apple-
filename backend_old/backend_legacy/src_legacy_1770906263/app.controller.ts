import {
  Body,
  Controller,
  Get,
  Headers,
  HttpException,
  Post,
  Req,
  UseGuards,
  VERSION_NEUTRAL,
  Version,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { randomUUID } from 'crypto';
import { Request } from 'express';
import { OnboardingJwtGuard } from './common/guards/onboarding-jwt.guard';

type StoredUser = {
  id: string;
  email: string;
  password: string;
  role: string;
  clubId: string | null;
  createdAt: string;
};

type StoredClub = {
  id: string;
  name: string;
  region: string;
  league: string | null;
  inviteCode: string;
  createdAt: string;
};

@Controller()
export class AppController {
  private readonly users: StoredUser[] = [
    {
      id: randomUUID(),
      email: 'coach@pitchinsights.app',
      password: 'pitchinsights',
      role: 'trainer',
      clubId: null,
      createdAt: new Date().toISOString(),
    },
  ];
  private readonly clubs: StoredClub[] = [
    {
      id: 'club-demo',
      name: 'PitchInsights FC',
      region: 'DE',
      league: 'Landesliga',
      inviteCode: 'PITCH-TEAM',
      createdAt: new Date().toISOString(),
    },
  ];
  private readonly refreshTokens = new Map<string, string>();

  constructor(private readonly jwtService: JwtService) {}

  @Get()
  @Version(VERSION_NEUTRAL)
  root() {
    return {
      status: 'ok',
      service: 'pitchinsights-backend',
      version: '1.0.0',
      time: new Date().toISOString(),
    };
  }

  @Get('bootstrap')
  @Version(VERSION_NEUTRAL)
  bootstrap() {
    console.log('[bootstrap] endpoint called');
    return {
      status: 'ok',
      service: 'pitchinsights-backend',
      version: '1.0.0',
      time: new Date().toISOString(),
    };
  }

  @Post('auth/register')
  @Version(VERSION_NEUTRAL)
  register(
    @Body()
    body: {
      email?: string;
      password?: string;
      passwordConfirmation?: string;
      role?: string;
      inviteCode?: string;
    },
  ) {
    const email = String(body?.email ?? '').trim().toLowerCase();
    const password = String(body?.password ?? '');
    const passwordConfirmation = String(body?.passwordConfirmation ?? '');
    const role = String(body?.role ?? '').trim().toLowerCase();
    const inviteCode = String(body?.inviteCode ?? '').trim();

    if (!email) {
      throw new HttpException('E-Mail ist erforderlich', 400);
    }
    if (!password) {
      throw new HttpException('Passwort ist erforderlich', 400);
    }
    if (password != passwordConfirmation) {
      throw new HttpException('Passwörter stimmen nicht überein', 400);
    }
    if (!role) {
      throw new HttpException('Rolle ist erforderlich', 400);
    }
    if (this.users.some((item) => item.email == email)) {
      throw new HttpException('E-Mail bereits registriert', 400);
    }

    let clubId: string | null = null;
    if (inviteCode) {
      const invitedClub = this.clubs.find((item) => item.inviteCode.toLowerCase() == inviteCode.toLowerCase());
      if (!invitedClub) {
        throw new HttpException('Einladungscode ungültig', 400);
      }
      clubId = invitedClub.id;
    }

    const created: StoredUser = {
      id: randomUUID(),
      email,
      password,
      role,
      clubId,
      createdAt: new Date().toISOString(),
    };
    this.users.push(created);

    const tokens = this.issueTokens(created);
    return {
      success: true,
      token: tokens.accessToken,
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
      user: this.publicUser(created),
    };
  }

  @Post('auth/login')
  @Version(VERSION_NEUTRAL)
  login(@Body() body: { email?: string; password?: string }) {
    const email = String(body?.email ?? '').trim().toLowerCase();
    const password = String(body?.password ?? '');
    if (!email || !password) {
      throw new HttpException('E-Mail und Passwort sind erforderlich', 400);
    }

    const user = this.users.find((item) => item.email == email && item.password == password);
    if (!user) {
      throw new HttpException('Ungültige Anmeldedaten', 400);
    }

    const tokens = this.issueTokens(user);
    return {
      success: true,
      token: tokens.accessToken,
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
      user: this.publicUser(user),
    };
  }

  @Post('auth/refresh')
  @Version(VERSION_NEUTRAL)
  refresh(@Body() body: { refreshToken?: string }) {
    const refreshToken = String(body?.refreshToken ?? '').trim();
    if (!refreshToken) {
      throw new HttpException('Refresh-Token fehlt', 400);
    }

    const storedUserId = this.refreshTokens.get(refreshToken);
    if (!storedUserId) {
      throw new HttpException('Refresh-Token ungültig', 400);
    }

    const payload = this.verifyToken(refreshToken);
    if (String(payload.type ?? '') != 'refresh') {
      throw new HttpException('Refresh-Token ungültig', 400);
    }

    const user = this.users.find((item) => item.id == storedUserId);
    if (!user) {
      throw new HttpException('Benutzer nicht gefunden', 400);
    }

    this.refreshTokens.delete(refreshToken);
    const tokens = this.issueTokens(user);
    return {
      success: true,
      token: tokens.accessToken,
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
      user: this.publicUser(user),
    };
  }

  @Post('auth/logout')
  @Version(VERSION_NEUTRAL)
  logout(@Body() body: { refreshToken?: string }, @Headers('authorization') _authorization?: string) {
    const refreshToken = String(body?.refreshToken ?? '').trim();
    if (refreshToken) {
      this.refreshTokens.delete(refreshToken);
    }
    return { success: true };
  }

  @Get('auth/me')
  @Version(VERSION_NEUTRAL)
  me(@Headers('authorization') authorization?: string) {
    const user = this.resolveUserFromAuthorization(authorization);
    return {
      ...this.publicUser(user),
      organizationId: user.clubId,
      clubMemberships: user.clubId
        ? [
            {
              id: `membership-${user.id}`,
              organizationId: user.clubId,
              teamId: null,
              role: user.role,
              status: 'active',
            },
          ]
        : [],
      onboardingState: {
        completed: user.clubId != null,
        completedAt: user.clubId != null ? new Date().toISOString() : null,
        lastStep: user.clubId != null ? 'complete' : 'club',
      },
    };
  }

  @Post('onboarding/create-club')
  @Version(VERSION_NEUTRAL)
  @UseGuards(OnboardingJwtGuard)
  createClub(
    @Req() req: Request & { user?: Record<string, unknown> },
    @Body() body: { name?: string; region?: string; league?: string },
  ) {
    const name = String(body?.name ?? '').trim();
    const region = String(body?.region ?? '').trim();
    const league = String(body?.league ?? '').trim();

    if (!name) {
      throw new HttpException('Vereinsname ist erforderlich', 400);
    }
    if (!region) {
      throw new HttpException('Region ist erforderlich', 400);
    }

    const user = this.requireGuardUser(req);
    const club: StoredClub = {
      id: randomUUID(),
      name,
      region,
      league: league.length === 0 ? null : league,
      inviteCode: this.generateInviteCode(),
      createdAt: new Date().toISOString(),
    };
    this.clubs.push(club);
    user.clubId = club.id;

    return {
      success: true,
      club: {
        id: club.id,
        name: club.name,
        region: club.region,
        league: club.league,
        inviteCode: club.inviteCode,
      },
    };
  }

  @Post('onboarding/join-club')
  @Version(VERSION_NEUTRAL)
  @UseGuards(OnboardingJwtGuard)
  joinClub(
    @Req() req: Request & { user?: Record<string, unknown> },
    @Body() body: { inviteCode?: string },
  ) {
    const inviteCode = String(body?.inviteCode ?? '').trim();
    if (!inviteCode) {
      throw new HttpException('Einladungscode ist erforderlich', 400);
    }

    const club = this.clubs.find((item) => item.inviteCode.toLowerCase() == inviteCode.toLowerCase());
    if (!club) {
      throw new HttpException('Einladungscode ungültig', 400);
    }

    const user = this.requireGuardUser(req);
    user.clubId = club.id;

    return {
      success: true,
      club: {
        id: club.id,
        name: club.name,
        region: club.region,
        league: club.league,
        inviteCode: club.inviteCode,
      },
    };
  }

  @Post('debug/reset-onboarding')
  @Version(VERSION_NEUTRAL)
  @UseGuards(OnboardingJwtGuard)
  resetOnboarding(@Req() req: Request & { user?: Record<string, unknown> }) {
    const user = this.requireGuardUser(req);
    user.clubId = null;

    return {
      success: true,
      user: this.publicUser(user),
    };
  }

  private issueTokens(user: StoredUser): { accessToken: string; refreshToken: string } {
    const secret = process.env.JWT_SECRET || 'pitchinsights-dev-secret';
    const accessToken = this.jwtService.sign(
      {
        sub: user.id,
        email: user.email,
        role: user.role,
        clubId: user.clubId,
        type: 'access',
      },
      { secret, expiresIn: '15m' },
    );
    const refreshToken = this.jwtService.sign(
      {
        sub: user.id,
        type: 'refresh',
      },
      { secret, expiresIn: '30d' },
    );
    this.refreshTokens.set(refreshToken, user.id);
    return { accessToken, refreshToken };
  }

  private resolveUserFromAuthorization(authorization?: string): StoredUser {
    const token = this.extractBearerToken(authorization);
    if (!token) {
      throw new HttpException('Authorization erforderlich', 400);
    }

    const payload = this.verifyToken(token);
    const userID = String(payload.sub ?? '');
    if (!userID) {
      throw new HttpException('Token ungültig', 400);
    }

    const user = this.users.find((item) => item.id == userID);
    if (!user) {
      throw new HttpException('Benutzer nicht gefunden', 400);
    }
    return user;
  }

  private verifyToken(token: string): Record<string, unknown> {
    const secret = process.env.JWT_SECRET || 'pitchinsights-dev-secret';
    try {
      return this.jwtService.verify(token, { secret }) as Record<string, unknown>;
    } catch {
      throw new HttpException('Token ungültig', 400);
    }
  }

  private requireGuardUser(req: Request & { user?: Record<string, unknown> }): StoredUser {
    const userID = String(req.user?.sub ?? '');
    if (!userID) {
      throw new HttpException('Token ungültig', 400);
    }
    const user = this.users.find((item) => item.id == userID);
    if (!user) {
      throw new HttpException('Benutzer nicht gefunden', 400);
    }
    return user;
  }

  private extractBearerToken(authorization?: string): string | null {
    if (!authorization) {
      return null;
    }
    const value = authorization.trim();
    if (!value.startsWith('Bearer ')) {
      return null;
    }
    return value.slice('Bearer '.length).trim();
  }

  private publicUser(user: StoredUser) {
    return {
      id: user.id,
      email: user.email,
      role: user.role,
      clubId: user.clubId,
      organizationId: user.clubId,
      createdAt: user.createdAt,
    };
  }

  private generateInviteCode(): string {
    return `INV-${randomUUID().slice(0, 8).toUpperCase()}`;
  }
}
