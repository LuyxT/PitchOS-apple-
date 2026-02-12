import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  Put,
  Query,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { JwtPayload } from '../auth/dto/jwt-payload.dto';
import {
  CreateReportDto,
  CreateTemplateDto,
  CreateTrainingPlanDto,
  LinkCalendarDto,
  UpdateTrainingPlanDto,
} from './dto/training-plan.dto';
import { TrainingService } from './training.service';

@ApiTags('training')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('training')
export class TrainingController {
  constructor(private readonly trainingService: TrainingService) {}

  @Get('plans')
  async list(@CurrentUser() user: JwtPayload, @Query('teamId') teamId?: string) {
    return this.trainingService.list(user, teamId);
  }

  @Get('plans/:id')
  async get(@CurrentUser() user: JwtPayload, @Param('id') id: string) {
    return this.trainingService.get(user, id);
  }

  @Post('plans')
  async create(@CurrentUser() user: JwtPayload, @Body() body: CreateTrainingPlanDto) {
    return this.trainingService.create(user, body);
  }

  @Patch('plans/:id')
  async update(
    @CurrentUser() user: JwtPayload,
    @Param('id') id: string,
    @Body() body: UpdateTrainingPlanDto,
  ) {
    return this.trainingService.update(user, id, body);
  }

  @Delete('plans/:id')
  async delete(@CurrentUser() user: JwtPayload, @Param('id') id: string) {
    return this.trainingService.delete(user, id);
  }

  @Post('templates')
  async createTemplate(@CurrentUser() user: JwtPayload, @Body() body: CreateTemplateDto) {
    return this.trainingService.createTemplate(user, body);
  }

  @Get('templates')
  async listTemplates(
    @CurrentUser() user: JwtPayload,
    @Query('teamId') teamId?: string,
    @Query('query') query?: string,
  ) {
    return this.trainingService.listTemplates(user, teamId, query);
  }

  @Post('plans/:id/duplicate')
  async duplicate(
    @CurrentUser() user: JwtPayload,
    @Param('id') id: string,
    @Body('name') name?: string,
  ) {
    return this.trainingService.duplicate(user, id, name);
  }

  @Post('plans/:id/live/start')
  async startLive(@CurrentUser() user: JwtPayload, @Param('id') id: string) {
    return this.trainingService.startLive(user, id);
  }

  @Put('plans/:id/live/state')
  async updateLive(
    @CurrentUser() user: JwtPayload,
    @Param('id') id: string,
    @Body() payload: Record<string, unknown>,
  ) {
    return this.trainingService.updateLive(user, id, payload);
  }

  @Post('plans/:id/report')
  async createReport(
    @CurrentUser() user: JwtPayload,
    @Param('id') id: string,
    @Body() body: CreateReportDto,
  ) {
    return this.trainingService.createReport(user, id, body);
  }

  @Get('plans/:id/report')
  async getReport(@CurrentUser() user: JwtPayload, @Param('id') id: string) {
    return this.trainingService.getReport(user, id);
  }

  @Post('plans/:id/calendar-link')
  async linkCalendar(
    @CurrentUser() user: JwtPayload,
    @Param('id') id: string,
    @Body() body: LinkCalendarDto,
  ) {
    return this.trainingService.linkCalendar(user, id, body);
  }
}
