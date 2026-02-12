import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';
import { PrismaService } from '../../prisma/prisma.service';
import { AuthUser } from '../../common/types/request-context';

interface JwtPayload {
  sub: string;
  email: string;
  type: 'access' | 'refresh';
}

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
  constructor(
    private readonly configService: ConfigService,
    private readonly prisma: PrismaService,
  ) {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false,
      secretOrKey: configService.get<string>('JWT_ACCESS_SECRET') ?? 'replace_me_access',
    });
  }

  async validate(payload: JwtPayload): Promise<AuthUser> {
    const user = await this.prisma.user.findUnique({
      where: { id: payload.sub },
      include: {
        memberships: {
          select: {
            clubId: true,
            teamId: true,
            role: true,
            status: true,
          },
        },
      },
    });

    if (!user || !user.isActive) {
      throw new Error('Unauthorized');
    }

    return {
      id: user.id,
      email: user.email,
      memberships: user.memberships.map((membership) => ({
        clubId: membership.clubId,
        teamId: membership.teamId,
        role: membership.role,
        status: membership.status,
      })),
    };
  }
}
