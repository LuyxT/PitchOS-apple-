import { Body, Controller, Get, Headers, HttpException, Post, VERSION_NEUTRAL, Version } from '@nestjs/common';
import { randomUUID } from 'crypto';

@Controller()
export class AppController {
  private readonly users = [
    {
      id: randomUUID(),
      email: 'coach@pitchinsights.app',
      password: 'pitchinsights',
      role: 'trainer',
      organizationId: 'org-pitchinsights-fc',
      createdAt: new Date().toISOString(),
    },
  ];
  private readonly accessTokens = new Map<string, string>();
  private readonly refreshTokens = new Map<string, string>();

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
  register(@Body() body: Record<string, unknown>) {
    const email = String(body?.email ?? '').trim().toLowerCase();
    const password = String(body?.password ?? '');
    const passwordConfirmation = String(body?.passwordConfirmation ?? '');
    const role = String(body?.role ?? 'trainer').trim().toLowerCase();

    if (!email || !password) {
      throw new HttpException('E-Mail und Passwort erforderlich', 400);
    }
    if (password != passwordConfirmation) {
      throw new HttpException('Passwörter stimmen nicht überein', 400);
    }
    if (this.users.some((item) => item.email.toLowerCase() == email)) {
      throw new HttpException('E-Mail bereits registriert', 409);
    }

    const created = {
      id: randomUUID(),
      email,
      password,
      role,
      organizationId: 'org-pitchinsights-fc',
      createdAt: new Date().toISOString(),
    };
    this.users.push(created);
    const tokens = this.issueTokens(created.id);
    return {
      ...tokens,
      user: this.userDTO(created),
    };
  }

  @Post('auth/login')
  @Version(VERSION_NEUTRAL)
  login(@Body() body: Record<string, unknown>) {
    const email = String(body?.email ?? '').trim().toLowerCase();
    const password = String(body?.password ?? '');
    const user = this.users.find((item) => item.email.toLowerCase() == email && item.password == password);

    if (!user) {
      throw new HttpException('Ungültige Anmeldedaten', 401);
    }

    const tokens = this.issueTokens(user.id);
    return {
      ...tokens,
      user: this.userDTO(user),
    };
  }

  @Post('auth/refresh')
  @Version(VERSION_NEUTRAL)
  refresh(@Body() body: Record<string, unknown>) {
    const refreshToken = String(body?.refreshToken ?? '');
    const userID = this.refreshTokens.get(refreshToken);
    if (!refreshToken || !userID) {
      throw new HttpException('Ungültiger Refresh-Token', 401);
    }

    this.refreshTokens.delete(refreshToken);
    const tokens = this.issueTokens(userID);
    const user = this.users.find((item) => item.id == userID);
    if (!user) {
      throw new HttpException('Benutzer nicht gefunden', 404);
    }

    return {
      ...tokens,
      user: this.userDTO(user),
    };
  }

  @Post('auth/logout')
  @Version(VERSION_NEUTRAL)
  logout(@Body() body: Record<string, unknown>, @Headers('authorization') authorization?: string) {
    const refreshToken = String(body?.refreshToken ?? '');
    if (refreshToken) {
      this.refreshTokens.delete(refreshToken);
    }
    const accessToken = this.extractBearerToken(authorization);
    if (accessToken) {
      this.accessTokens.delete(accessToken);
    }
    return {};
  }

  @Get('auth/me')
  @Version(VERSION_NEUTRAL)
  me(@Headers('authorization') authorization?: string) {
    const accessToken = this.extractBearerToken(authorization);
    if (!accessToken) {
      throw new HttpException('Authorization erforderlich', 401);
    }

    const userID = this.accessTokens.get(accessToken);
    if (!userID) {
      throw new HttpException('Ungültiger Access-Token', 401);
    }

    const user = this.users.find((item) => item.id == userID);
    if (!user) {
      throw new HttpException('Benutzer nicht gefunden', 404);
    }

    return {
      ...this.userDTO(user),
      clubMemberships: [
        {
          id: `membership-${user.id}`,
          organizationId: user.organizationId,
          teamId: 'team-first',
          role: user.role,
          status: 'active',
        },
      ],
      onboardingState: {
        completed: false,
        completedAt: null,
        lastStep: 'role',
      },
    };
  }

  private issueTokens(userID: string): { accessToken: string; refreshToken: string } {
    const accessToken = `pi_access_${randomUUID()}`;
    const refreshToken = `pi_refresh_${randomUUID()}`;
    this.accessTokens.set(accessToken, userID);
    this.refreshTokens.set(refreshToken, userID);
    return { accessToken, refreshToken };
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

  private userDTO(user: { id: string; email: string; organizationId: string; createdAt: string }) {
    return {
      id: user.id,
      email: user.email,
      organizationId: user.organizationId,
      createdAt: user.createdAt,
    };
  }
}
