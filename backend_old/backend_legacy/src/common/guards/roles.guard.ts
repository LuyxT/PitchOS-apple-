import { CanActivate, ExecutionContext, Injectable } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { RoleType } from '@prisma/client';
import { ROLES_KEY } from '../decorators/roles.decorator';
import { AppError } from '../filters/app-error';
import { RequestWithContext } from '../types/request-context';

@Injectable()
export class RolesGuard implements CanActivate {
  constructor(private readonly reflector: Reflector) {}

  canActivate(context: ExecutionContext): boolean {
    const requiredRoles = this.reflector.getAllAndOverride<RoleType[]>(ROLES_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);

    if (!requiredRoles || requiredRoles.length === 0) {
      return true;
    }

    const request = context.switchToHttp().getRequest<RequestWithContext>();
    const user = request.user;
    if (!user) {
      throw new AppError('unauthorized', 'Authentication required', null, 401);
    }

    const hasRole = user.memberships.some((membership) => requiredRoles.includes(membership.role));
    if (!hasRole) {
      throw new AppError('forbidden', 'Missing required role', { requiredRoles }, 403);
    }

    return true;
  }
}
