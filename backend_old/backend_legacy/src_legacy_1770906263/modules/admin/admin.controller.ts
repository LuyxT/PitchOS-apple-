import {
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { JwtPayload } from '../auth/dto/jwt-payload.dto';
import { RoleType } from '@prisma/client';
import { AdminService } from './admin.service';
import {
  CreateInvitationDto,
  CreateRoleDto,
  CreateSeasonDto,
  UpdateInvitationDto,
  UpdateRoleDto,
  UpdateSeasonDto,
} from './dto/admin.dto';

@ApiTags('admin')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(RoleType.ADMIN, RoleType.TEAM_MANAGER)
@Controller('admin')
export class AdminController {
  constructor(private readonly adminService: AdminService) {}

  @Get('dashboard')
  async dashboard(@CurrentUser() user: JwtPayload) {
    return this.adminService.dashboard(user);
  }

  @Get('roles')
  async roles(@CurrentUser() user: JwtPayload) {
    return this.adminService.roles(user);
  }

  @Post('roles')
  async createRole(@CurrentUser() user: JwtPayload, @Body() body: CreateRoleDto) {
    return this.adminService.createRole(user, body);
  }

  @Patch('roles/:id')
  async updateRole(
    @CurrentUser() user: JwtPayload,
    @Param('id') id: string,
    @Body() body: UpdateRoleDto,
  ) {
    return this.adminService.updateRole(user, id, body);
  }

  @Get('invitations')
  async invitations(@CurrentUser() user: JwtPayload) {
    return this.adminService.invitations(user);
  }

  @Post('invitations')
  async createInvitation(@CurrentUser() user: JwtPayload, @Body() body: CreateInvitationDto) {
    return this.adminService.createInvitation(user, body);
  }

  @Patch('invitations/:id')
  async updateInvitation(
    @CurrentUser() user: JwtPayload,
    @Param('id') id: string,
    @Body() body: UpdateInvitationDto,
  ) {
    return this.adminService.updateInvitation(user, id, body);
  }

  @Get('seasons')
  async seasons(@CurrentUser() user: JwtPayload) {
    return this.adminService.seasons(user);
  }

  @Post('seasons')
  async createSeason(@CurrentUser() user: JwtPayload, @Body() body: CreateSeasonDto) {
    return this.adminService.createSeason(user, body);
  }

  @Patch('seasons/:id')
  async updateSeason(
    @CurrentUser() user: JwtPayload,
    @Param('id') id: string,
    @Body() body: UpdateSeasonDto,
  ) {
    return this.adminService.updateSeason(user, id, body);
  }

  @Get('audit')
  async audit(
    @CurrentUser() user: JwtPayload,
    @Query('actorUserId') actorUserId?: string,
    @Query('area') area?: string,
  ) {
    return this.adminService.auditLog(user, actorUserId, area);
  }
}
