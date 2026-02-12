import { CanActivate, ExecutionContext, Injectable } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { PERMISSIONS_KEY } from '../decorators/permissions.decorator';
import { AppError } from '../filters/app-error';
import { RequestWithContext } from '../types/request-context';
import { Permission, hasPermission } from '../utils/permissions';

@Injectable()
export class PermissionsGuard implements CanActivate {
  constructor(private readonly reflector: Reflector) {}

  canActivate(context: ExecutionContext): boolean {
    const requiredPermissions = this.reflector.getAllAndOverride<Permission[]>(PERMISSIONS_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);

    if (!requiredPermissions || requiredPermissions.length === 0) {
      return true;
    }

    const request = context.switchToHttp().getRequest<RequestWithContext>();
    const user = request.user;
    if (!user) {
      throw new AppError('unauthorized', 'Authentication required', null, 401);
    }

    const userRoles = Array.from(new Set(user.memberships.map((membership) => membership.role)));
    const hasAll = requiredPermissions.every((permission) => hasPermission(userRoles, permission));

    if (!hasAll) {
      throw new AppError('forbidden', 'Missing required permission', { requiredPermissions }, 403);
    }

    return true;
  }
}
