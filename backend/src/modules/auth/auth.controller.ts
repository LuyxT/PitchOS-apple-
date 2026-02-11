import { Body, Controller, Get, Post, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { AuthService } from './auth.service';
import { LoginDto } from './dto/login.dto';
import { RefreshTokenDto } from './dto/refresh-token.dto';
import { RegisterDto } from './dto/register.dto';
import { LogoutDto } from './dto/logout.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { JwtPayload } from './dto/jwt-payload.dto';
import { PrismaService } from '../../prisma/prisma.service';

@ApiTags('auth')
@Controller('auth')
export class AuthController {
  constructor(
    private readonly authService: AuthService,
    private readonly prisma: PrismaService,
  ) { }

  @Post('login')
  async login(@Body() body: LoginDto) {
    return this.authService.login(body);
  }

  @Post('register')
  async register(@Body() body: RegisterDto) {
    return this.authService.register(body);
  }

  @Post('refresh')
  async refresh(@Body() body: RefreshTokenDto) {
    return this.authService.refresh(body.refreshToken);
  }

  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard)
  @Post('logout')
  async logout(@CurrentUser() user: JwtPayload, @Body() body: LogoutDto) {
    await this.authService.logout(user.sub, body.refreshToken);
    return { success: true };
  }

  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard)
  @Get('me')
  async me(@CurrentUser() user: JwtPayload) {
    const me = await this.prisma.user.findUnique({
      where: { id: user.sub },
      include: {
        roles: { include: { role: true } },
        memberships: true,
        clubMemberships: true,
        organization: true,
        onboardingState: true,
      },
    });
    if (!me) {
      return null;
    }

    return {
      id: me.id,
      email: me.email,
      organizationId: me.organizationId,
      createdAt: me.createdAt,
      clubMemberships: me.clubMemberships.map((membership) => ({
        id: membership.id,
        organizationId: membership.organizationId,
        teamId: membership.teamId,
        role: membership.role,
        status: membership.status,
      })),
      onboardingState: me.onboardingState
        ? {
          completed: me.onboardingState.completed,
          completedAt: me.onboardingState.completedAt,
          lastStep: me.onboardingState.lastStep,
        }
        : null,
    };
  }
}
