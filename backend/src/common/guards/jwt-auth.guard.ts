import {
  CanActivate,
  ExecutionContext,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { Reflector } from '@nestjs/core';
import { UserRole } from '@prisma/client';
import { ERROR_CODES } from '../constants/error-codes';
import { IS_PUBLIC_KEY } from '../decorators/public.decorator';
import { RequestWithContext } from '../interfaces/request-context.interface';
import { getEnv } from '../../config/env';
import { PrismaService } from '../../prisma/prisma.service';

interface AccessTokenPayload {
  sub: string;
  email: string;
  role: UserRole;
}

@Injectable()
export class JwtAuthGuard implements CanActivate {
  constructor(
    private readonly reflector: Reflector,
    private readonly jwtService: JwtService,
    private readonly prisma: PrismaService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const isPublic = this.reflector.getAllAndOverride<boolean>(IS_PUBLIC_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);

    if (isPublic) {
      return true;
    }

    const request = context.switchToHttp().getRequest<RequestWithContext>();
    const header = request.headers.authorization;

    if (!header || !header.startsWith('Bearer ')) {
      throw new UnauthorizedException({
        code: ERROR_CODES.unauthorized,
        message: 'Missing bearer token.',
      });
    }

    const token = header.slice(7).trim();

    if (!token) {
      throw new UnauthorizedException({
        code: ERROR_CODES.unauthorized,
        message: 'Invalid bearer token.',
      });
    }

    let payload: AccessTokenPayload;

    try {
      payload = await this.jwtService.verifyAsync<AccessTokenPayload>(token, {
        secret: getEnv().JWT_ACCESS_SECRET,
      });
    } catch {
      throw new UnauthorizedException({
        code: ERROR_CODES.unauthorized,
        message: 'Access token is invalid or expired.',
      });
    }

    const user = await this.prisma.user.findUnique({
      where: { id: payload.sub },
    });

    if (!user) {
      throw new UnauthorizedException({
        code: ERROR_CODES.unauthorized,
        message: 'User not found.',
      });
    }

    request.user = {
      id: user.id,
      email: user.email,
      role: user.role,
      clubId: user.clubId,
      teamId: user.teamId,
    };

    return true;
  }
}
