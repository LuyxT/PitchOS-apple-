import { Body, Controller, Get, Param, Patch, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { ProfilesService } from './profiles.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { JwtPayload } from '../auth/dto/jwt-payload.dto';
import { UpdateProfileDto } from './dto/update-profile.dto';

@ApiTags('profiles')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('profiles')
export class ProfilesController {
  constructor(private readonly profilesService: ProfilesService) {}

  @Get()
  async list(@CurrentUser() user: JwtPayload) {
    return this.profilesService.list(user);
  }

  @Get(':userId')
  async getByUser(@CurrentUser() user: JwtPayload, @Param('userId') userId: string) {
    return this.profilesService.getByUserId(user, userId);
  }

  @Patch(':userId')
  async update(
    @CurrentUser() user: JwtPayload,
    @Param('userId') userId: string,
    @Body() body: UpdateProfileDto,
  ) {
    return this.profilesService.update(user, userId, body);
  }
}
