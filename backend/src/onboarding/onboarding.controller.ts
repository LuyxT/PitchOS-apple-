import { Body, Controller, Post } from '@nestjs/common';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { AuthenticatedUser } from '../common/interfaces/request-context.interface';
import { TeamService } from '../team/team.service';
import { CreateClubDto } from './dto/create-club.dto';
import { CreateOnboardingTeamDto } from './dto/create-team.dto';
import { OnboardingService } from './onboarding.service';

@Controller('onboarding')
export class OnboardingController {
  constructor(
    private readonly onboardingService: OnboardingService,
    private readonly teamService: TeamService,
  ) {}

  @Post('club')
  async createClub(
    @CurrentUser() user: AuthenticatedUser,
    @Body() dto: CreateClubDto,
  ) {
    return this.onboardingService.createClub(user.id, dto);
  }

  @Post('team')
  async createTeam(
    @CurrentUser() user: AuthenticatedUser,
    @Body() dto: CreateOnboardingTeamDto,
  ) {
    return this.teamService.createOrAttachTeam(user.id, dto);
  }
}
