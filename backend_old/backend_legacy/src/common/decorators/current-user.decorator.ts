import { createParamDecorator, ExecutionContext } from '@nestjs/common';
import { AuthUser } from '../types/request-context';

export const CurrentUser = createParamDecorator((_: unknown, ctx: ExecutionContext): AuthUser | undefined => {
  const request = ctx.switchToHttp().getRequest();
  return request.user;
});
