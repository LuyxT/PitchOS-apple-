import { RoleType } from '@prisma/client';

export class JwtPayload {
  sub!: string;
  orgId!: string;
  teamIds!: string[];
  roles!: RoleType[];
  iat?: number;
  exp?: number;
}
