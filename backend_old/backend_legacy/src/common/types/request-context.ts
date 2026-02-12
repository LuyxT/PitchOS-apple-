import { Request } from 'express';
import { RoleType } from '@prisma/client';

export interface AuthUser {
  id: string;
  email: string;
  memberships: Array<{
    clubId: string;
    teamId: string | null;
    role: RoleType;
    status: string;
  }>;
}

export interface RequestContext {
  requestId: string;
}

export interface RequestWithContext extends Request {
  context: RequestContext;
  user?: AuthUser;
}
