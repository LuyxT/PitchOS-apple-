import { Body, Controller, Get, Post, Query } from '@nestjs/common';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { AuthenticatedUser } from '../common/interfaces/request-context.interface';
import { CreateTeamDto } from './dto/create-team.dto';
import { ListTeamDto } from './dto/list-team.dto';
import { TeamService } from './team.service';

@Controller('team')
export class TeamController {
  constructor(private readonly teamService: TeamService) {}

  @Post()
  async createTeam(
    @CurrentUser() user: AuthenticatedUser,
    @Body() dto: CreateTeamDto,
  ) {
    return this.teamService.createOrAttachTeam(user.id, dto);
  }

  @Get()
  async listTeams(
    @CurrentUser() user: AuthenticatedUser,
    @Query() query: ListTeamDto,
  ) {
    return this.teamService.listTeams(user.id, query.clubId);
  }
}
