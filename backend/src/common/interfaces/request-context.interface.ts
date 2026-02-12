import { UserRole } from '@prisma/client';
import { Request } from 'express';

export interface AuthenticatedUser {
  id: string;
  email: string;
  role: UserRole;
  clubId: string | null;
  teamId: string | null;
}

export interface RequestWithContext extends Request {
  requestId?: string;
  user?: AuthenticatedUser;
}
