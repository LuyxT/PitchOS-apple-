import {
  UnauthorizedException,
  createParamDecorator,
  ExecutionContext,
} from '@nestjs/common';
import { ERROR_CODES } from '../constants/error-codes';
import {
  AuthenticatedUser,
  RequestWithContext,
} from '../interfaces/request-context.interface';

export const CurrentUser = createParamDecorator(
  (_: unknown, context: ExecutionContext): AuthenticatedUser => {
    const request = context.switchToHttp().getRequest<RequestWithContext>();
    if (!request.user) {
      throw new UnauthorizedException({
        code: ERROR_CODES.unauthorized,
        message: 'User context is missing.',
      });
    }

    return request.user;
  },
);
