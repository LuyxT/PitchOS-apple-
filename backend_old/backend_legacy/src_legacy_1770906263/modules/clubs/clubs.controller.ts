import { Body, Controller, Get, Post, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { JwtPayload } from '../auth/dto/jwt-payload.dto';
import { ClubsService } from './clubs.service';
import { CreateClubDto } from './dto/create-club.dto';
import { JoinClubDto } from './dto/join-club.dto';

@ApiTags('clubs')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('clubs')
export class ClubsController {
  constructor(private readonly clubsService: ClubsService) {}

  @Get('search')
  async search(@Query('query') query: string, @Query('region') region?: string) {
    return this.clubsService.search(query ?? '', region);
  }

  @Post()
  async create(@CurrentUser() user: JwtPayload, @Body() body: CreateClubDto) {
    return this.clubsService.create(user.sub, body);
  }

  @Post('join')
  async join(@CurrentUser() user: JwtPayload, @Body() body: JoinClubDto) {
    return this.clubsService.join(user.sub, body);
  }
}
