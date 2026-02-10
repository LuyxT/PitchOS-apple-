import { Body, Controller, Delete, Get, Param, Patch, Post, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { JwtPayload } from '../auth/dto/jwt-payload.dto';
import { TacticsService } from './tactics.service';
import { CreateTacticsBoardDto, UpdateTacticsBoardDto } from './dto/tactics-board.dto';

@ApiTags('tactics')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('tactics/boards')
export class TacticsController {
  constructor(private readonly tacticsService: TacticsService) {}

  @Get()
  async list(@CurrentUser() user: JwtPayload, @Query('teamId') teamId?: string) {
    return this.tacticsService.list(user, teamId);
  }

  @Get(':id')
  async get(@CurrentUser() user: JwtPayload, @Param('id') id: string) {
    return this.tacticsService.get(user, id);
  }

  @Post()
  async create(@CurrentUser() user: JwtPayload, @Body() body: CreateTacticsBoardDto) {
    return this.tacticsService.create(user, body);
  }

  @Patch(':id')
  async update(
    @CurrentUser() user: JwtPayload,
    @Param('id') id: string,
    @Body() body: UpdateTacticsBoardDto,
  ) {
    return this.tacticsService.update(user, id, body);
  }

  @Delete(':id')
  async remove(@CurrentUser() user: JwtPayload, @Param('id') id: string) {
    return this.tacticsService.remove(user, id);
  }
}
