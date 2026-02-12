import { CanActivate, ExecutionContext, HttpException, Injectable } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';

@Injectable()
export class OnboardingJwtGuard implements CanActivate {
  constructor(private readonly jwtService: JwtService) {}

  canActivate(context: ExecutionContext): boolean {
    const request = context.switchToHttp().getRequest<{ headers: Record<string, string | undefined>; user?: Record<string, unknown> }>();
    const authorization = request.headers?.authorization ?? '';
    if (!authorization.startsWith('Bearer ')) {
      throw new HttpException('Token fehlt', 400);
    }

    const token = authorization.slice('Bearer '.length).trim();
    if (!token) {
      throw new HttpException('Token fehlt', 400);
    }

    try {
      const payload = this.jwtService.verify(token, {
        secret: process.env.JWT_SECRET || 'pitchinsights-dev-secret',
      }) as Record<string, unknown>;
      request.user = payload;
      return true;
    } catch {
      throw new HttpException('Token ungültig', 400);
    }
  }
}
