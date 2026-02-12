import { RoleType } from '@prisma/client';

export class JwtPayload {
  sub!: string;
  orgId?: string | null;
  teamIds!: string[];
  roles!: RoleType[];
  iat?: number;
  exp?: number;
}
