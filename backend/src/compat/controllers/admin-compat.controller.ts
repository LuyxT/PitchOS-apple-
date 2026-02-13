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

@Controller('admin')
export class AdminCompatController {
  constructor(private readonly compatService: CompatService) {}

  @Get('tasks')
  tasks() {
    return this.compatService.emptyArray();
  }

  @Get('bootstrap')
  bootstrap() {
    return this.compatService.adminBootstrap();
  }

  @Post('persons')
  createPerson(@Body() _body: Record<string, unknown>) {
    return this.compatService.adminPerson();
  }

  @Put('persons/:personId')
  updatePerson(
    @Param('personId') personId: string,
    @Body() _body: Record<string, unknown>,
  ) {
    return this.compatService.adminPerson(personId);
  }

  @Delete('persons/:personId')
  deletePerson(@Param('personId') _personId: string) {
    return this.compatService.emptyObject();
  }

  @Post('groups')
  createGroup(@Body() _body: Record<string, unknown>) {
    return this.compatService.adminGroup();
  }

  @Put('groups/:groupId')
  updateGroup(
    @Param('groupId') groupId: string,
    @Body() _body: Record<string, unknown>,
  ) {
    return this.compatService.adminGroup(groupId);
  }

  @Delete('groups/:groupId')
  deleteGroup(@Param('groupId') _groupId: string) {
    return this.compatService.emptyObject();
  }

  @Post('invitations')
  createInvitation(@Body() _body: Record<string, unknown>) {
    return this.compatService.adminInvitation();
  }

  @Put('invitations/:invitationId/status')
  updateInvitationStatus(
    @Param('invitationId') invitationId: string,
    @Body() _body: Record<string, unknown>,
  ) {
    return this.compatService.adminInvitation(invitationId);
  }

  @Post('invitations/:invitationId/resend')
  resendInvitation(@Param('invitationId') invitationId: string) {
    return this.compatService.adminInvitation(invitationId);
  }

  @Get('audit')
  audit(@Query('cursor') _cursor?: string, @Query('limit') _limit?: string) {
    return this.compatService.adminAuditPage();
  }

  @Post('seasons')
  createSeason(@Body() _body: Record<string, unknown>) {
    return this.compatService.adminSeason();
  }

  @Put('seasons/:seasonId')
  updateSeason(
    @Param('seasonId') seasonId: string,
    @Body() _body: Record<string, unknown>,
  ) {
    return this.compatService.adminSeason(seasonId);
  }

  @Put('seasons/:seasonId/status')
  updateSeasonStatus(
    @Param('seasonId') seasonId: string,
    @Body() _body: Record<string, unknown>,
  ) {
    return this.compatService.adminSeason(seasonId);
  }

  @Post('seasons/activate')
  activateSeason(@Body() _body: Record<string, unknown>) {
    return this.compatService.emptyObject();
  }

  @Post('seasons/:seasonId/duplicate-roster')
  duplicateRoster(
    @Param('seasonId') _seasonId: string,
    @Body() _body: Record<string, unknown>,
  ) {
    return this.compatService.emptyObject();
  }

  @Put('settings/club')
  saveClubSettings(@Body() _body: Record<string, unknown>) {
    return this.compatService.adminClubSettings();
  }

  @Put('settings/messenger')
  saveMessengerRules(@Body() _body: Record<string, unknown>) {
    return this.compatService.adminMessengerRules();
  }
}
