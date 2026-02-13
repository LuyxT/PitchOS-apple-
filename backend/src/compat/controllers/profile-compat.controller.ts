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
} from '@nestjs/common';
import { CompatService } from '../compat.service';

@Controller()
export class ProfileCompatController {
  constructor(private readonly compatService: CompatService) {}

  @Get('profile')
  getProfile() {
    return this.compatService.coachProfile();
  }

  @Post('profile')
  submitProfile(@Body() _body: Record<string, unknown>) {
    return this.compatService.personProfile();
  }

  @Get('profiles')
  getProfiles() {
    return this.compatService.emptyArray();
  }

  @Post('profiles')
  createProfile(@Body() _body: Record<string, unknown>) {
    return this.compatService.personProfile();
  }

  @Put('profiles/:id')
  updateProfile(@Param('id') id: string, @Body() _body: Record<string, unknown>) {
    return this.compatService.personProfile(id);
  }

  @Patch('profiles/:id')
  patchProfile(@Param('id') id: string, @Body() _body: Record<string, unknown>) {
    return this.compatService.personProfile(id);
  }

  @Delete('profiles/:id')
  deleteProfile(@Param('id') _id: string) {
    return this.compatService.emptyObject();
  }

  @Get('profiles/audit')
  profileAudit(@Query('profileId') profileId?: string) {
    if (profileId) {
      return [this.compatService.profileAuditEntry(profileId)];
    }
    return this.compatService.emptyArray();
  }
}
