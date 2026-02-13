import { Body, Controller, Get, Post, Put } from '@nestjs/common';
import { CompatService } from '../compat.service';

@Controller('settings')
export class SettingsCompatController {
  constructor(private readonly compatService: CompatService) {}

  @Get('bootstrap')
  bootstrap() {
    return this.compatService.settingsBootstrap();
  }

  @Put('presentation')
  presentation(@Body() _body: Record<string, unknown>) {
    return this.compatService.presentationSettings();
  }

  @Put('notifications')
  notifications(@Body() _body: Record<string, unknown>) {
    return this.compatService.notificationSettings();
  }

  @Get('security')
  security() {
    return this.compatService.securitySettings();
  }

  @Post('security/password')
  changePassword(@Body() _body: Record<string, unknown>) {
    return this.compatService.emptyObject();
  }

  @Post('security/two-factor')
  twoFactor(@Body() _body: Record<string, unknown>) {
    return this.compatService.securitySettings();
  }

  @Post('security/sessions/revoke')
  revokeSession(@Body() _body: Record<string, unknown>) {
    return this.compatService.securitySettings();
  }

  @Post('security/sessions/revoke-all')
  revokeAllSessions() {
    return this.compatService.securitySettings();
  }

  @Get('app-info')
  appInfo() {
    return this.compatService.appInfoSettings();
  }

  @Post('feedback')
  submitFeedback(@Body() _body: Record<string, unknown>) {
    return this.compatService.emptyObject();
  }

  @Post('account/context')
  switchContext(@Body() _body: Record<string, unknown>) {
    return this.compatService.accountSettings();
  }

  @Post('account/deactivate')
  deactivate() {
    return this.compatService.emptyObject();
  }

  @Post('account/leave-team')
  leaveTeam() {
    return this.compatService.emptyObject();
  }
}
