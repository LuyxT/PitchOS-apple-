import { Body, Controller, Delete, Get, Param, Patch, Post, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { UsersService } from './users.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { JwtPayload } from '../auth/dto/jwt-payload.dto';
import { RoleType } from '@prisma/client';
import { CreateUserDto } from './dto/create-user.dto';
import { UpdateUserDto } from './dto/update-user.dto';

@ApiTags('users')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('users')
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  @Roles(RoleType.ADMIN, RoleType.TEAM_MANAGER, RoleType.TRAINER)
  @Get()
  async list(@CurrentUser() user: JwtPayload) {
    return this.usersService.list(user.orgId);
  }

  @Get('me')
  async me(@CurrentUser() user: JwtPayload) {
    return this.usersService.get(user.orgId, user.sub);
  }

  @Roles(RoleType.ADMIN, RoleType.TEAM_MANAGER)
  @Get(':id')
  async get(@CurrentUser() user: JwtPayload, @Param('id') id: string) {
    return this.usersService.get(user.orgId, id);
  }

  @Roles(RoleType.ADMIN, RoleType.TEAM_MANAGER)
  @Post()
  async create(@CurrentUser() user: JwtPayload, @Body() body: CreateUserDto) {
    return this.usersService.create(user.orgId, body);
  }

  @Roles(RoleType.ADMIN, RoleType.TEAM_MANAGER)
  @Patch(':id')
  async update(
    @CurrentUser() user: JwtPayload,
    @Param('id') id: string,
    @Body() body: UpdateUserDto,
  ) {
    return this.usersService.update(user.orgId, id, body);
  }

  @Roles(RoleType.ADMIN)
  @Delete(':id')
  async remove(@CurrentUser() user: JwtPayload, @Param('id') id: string) {
    return this.usersService.remove(user.orgId, id);
  }
}
