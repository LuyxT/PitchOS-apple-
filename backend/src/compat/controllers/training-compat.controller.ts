import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Post,
  Put,
  Query,
} from '@nestjs/common';
import { CompatService } from '../compat.service';

@Controller('training')
export class TrainingCompatController {
  constructor(private readonly compatService: CompatService) {}

  @Get('plans')
  plans(@Query('cursor') _cursor?: string, @Query('limit') _limit?: string) {
    return this.compatService.trainingPlansPage();
  }

  @Post('plans')
  createPlan(@Body() _body: Record<string, unknown>) {
    return this.compatService.trainingPlan();
  }

  @Get('plans/:planId')
  plan(@Param('planId') planId: string) {
    return this.compatService.trainingPlanEnvelope(planId);
  }

  @Put('plans/:planId')
  updatePlan(
    @Param('planId') planId: string,
    @Body() _body: Record<string, unknown>,
  ) {
    return this.compatService.trainingPlan(planId);
  }

  @Delete('plans/:planId')
  deletePlan(@Param('planId') _planId: string) {
    return this.compatService.emptyObject();
  }

  @Put('plans/:planId/phases')
  savePhases(
    @Param('planId') _planId: string,
    @Body() _body: Record<string, unknown>,
  ) {
    return this.compatService.emptyArray();
  }

  @Put('plans/:planId/exercises')
  saveExercises(
    @Param('planId') _planId: string,
    @Body() _body: Record<string, unknown>,
  ) {
    return this.compatService.emptyArray();
  }

  @Get('templates')
  templates(@Query('cursor') _cursor?: string, @Query('limit') _limit?: string) {
    return this.compatService.trainingTemplatesPage();
  }

  @Post('templates')
  createTemplate(@Body() _body: Record<string, unknown>) {
    return this.compatService.trainingTemplate();
  }

  @Post('plans/:planId/groups')
  createGroup(
    @Param('planId') planId: string,
    @Body() _body: Record<string, unknown>,
  ) {
    return this.compatService.trainingGroup(planId);
  }

  @Put('groups/:groupId')
  updateGroup(
    @Param('groupId') groupId: string,
    @Body() _body: Record<string, unknown>,
  ) {
    return this.compatService.trainingGroup(undefined, groupId);
  }

  @Put('groups/:groupId/briefing')
  saveGroupBriefing(
    @Param('groupId') groupId: string,
    @Body() _body: Record<string, unknown>,
  ) {
    return this.compatService.trainingGroupBriefing(groupId);
  }

  @Put('plans/:planId/participants')
  saveParticipants(
    @Param('planId') _planId: string,
    @Body() _body: Record<string, unknown>,
  ) {
    return this.compatService.emptyArray();
  }

  @Post('plans/:planId/live/start')
  startLive(
    @Param('planId') planId: string,
    @Body() _body: Record<string, unknown>,
  ) {
    return this.compatService.trainingPlan(planId);
  }

  @Put('plans/:planId/live/state')
  saveLiveState(
    @Param('planId') planId: string,
    @Body() _body: Record<string, unknown>,
  ) {
    return this.compatService.trainingPlanEnvelope(planId);
  }

  @Post('plans/:planId/live/deviations')
  createDeviation(
    @Param('planId') planId: string,
    @Body() _body: Record<string, unknown>,
  ) {
    return this.compatService.trainingDeviation(planId);
  }

  @Post('plans/:planId/report')
  createReport(
    @Param('planId') planId: string,
    @Body() _body: Record<string, unknown>,
  ) {
    return this.compatService.trainingReport(planId);
  }

  @Get('plans/:planId/report')
  report(@Param('planId') planId: string) {
    return this.compatService.trainingReport(planId);
  }

  @Post('plans/:planId/calendar-link')
  linkCalendar(
    @Param('planId') _planId: string,
    @Body() _body: Record<string, unknown>,
  ) {
    return this.compatService.calendarEvent();
  }

  @Post('plans/:planId/duplicate')
  duplicatePlan(
    @Param('planId') _planId: string,
    @Body() _body: Record<string, unknown>,
  ) {
    return this.compatService.trainingPlan();
  }
}
