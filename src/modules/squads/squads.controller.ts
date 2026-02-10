import { Body, Controller, Delete, Get, Param, Patch, Post, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { SquadsService } from './squads.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { JwtPayload } from '../auth/dto/jwt-payload.dto';
import { RoleType } from '@prisma/client';
import { CreatePlayerDto } from './dto/create-player.dto';
import { UpdatePlayerDto } from './dto/update-player.dto';

@ApiTags('squads')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('squads')
export class SquadsController {
  constructor(private readonly squadsService: SquadsService) {}

  @Get('players')
  async list(
    @CurrentUser() user: JwtPayload,
    @Query('teamId') teamId?: string,
    @Query('position') position?: string,
    @Query('fitness') fitness?: string,
  ) {
    return this.squadsService.list(user, teamId, position, fitness);
  }

  @Roles(RoleType.ADMIN, RoleType.TRAINER, RoleType.CO_TRAINER, RoleType.TEAM_MANAGER)
  @Post('players')
  async create(@CurrentUser() user: JwtPayload, @Body() body: CreatePlayerDto) {
    return this.squadsService.create(user, body);
  }

  @Roles(RoleType.ADMIN, RoleType.TRAINER, RoleType.CO_TRAINER, RoleType.TEAM_MANAGER)
  @Patch('players/:id')
  async update(
    @CurrentUser() user: JwtPayload,
    @Param('id') id: string,
    @Body() body: UpdatePlayerDto,
  ) {
    return this.squadsService.update(user, id, body);
  }

  @Roles(RoleType.ADMIN, RoleType.TRAINER, RoleType.TEAM_MANAGER)
  @Delete('players/:id')
  async remove(@CurrentUser() user: JwtPayload, @Param('id') id: string) {
    return this.squadsService.remove(user, id);
  }

  @Get('positions/overview')
  async positionOverview(@CurrentUser() user: JwtPayload, @Query('teamId') teamId?: string) {
    return this.squadsService.positionOverview(user, teamId);
  }
}
