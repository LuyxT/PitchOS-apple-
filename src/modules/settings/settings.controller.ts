import { Body, Controller, Get, Patch, Post, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { JwtPayload } from '../auth/dto/jwt-payload.dto';
import { SettingsService } from './settings.service';
import { SubmitFeedbackDto, UpdateSettingsDto } from './dto/settings.dto';

@ApiTags('settings')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('settings')
export class SettingsController {
  constructor(private readonly settingsService: SettingsService) {}

  @Get()
  async get(@CurrentUser() user: JwtPayload) {
    return this.settingsService.get(user);
  }

  @Patch()
  async update(@CurrentUser() user: JwtPayload, @Body() body: UpdateSettingsDto) {
    return this.settingsService.update(user, body);
  }

  @Get('security/sessions')
  async sessions(@CurrentUser() user: JwtPayload) {
    return this.settingsService.activeSessions(user);
  }

  @Post('security/logout-all')
  async logoutAll(@CurrentUser() user: JwtPayload) {
    return this.settingsService.logoutAll(user);
  }

  @Get('app-info')
  async appInfo() {
    return this.settingsService.appInfo();
  }

  @Post('feedback')
  async feedback(@CurrentUser() user: JwtPayload, @Body() body: SubmitFeedbackDto) {
    return this.settingsService.submitFeedback(user, body);
  }
}
