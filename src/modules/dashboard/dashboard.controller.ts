import { Controller, Get, Param, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { JwtPayload } from '../auth/dto/jwt-payload.dto';
import { DashboardService } from './dashboard.service';

@ApiTags('dashboard')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('dashboard')
export class DashboardController {
  constructor(private readonly dashboardService: DashboardService) {}

  @Get('overview')
  async overview(@CurrentUser() user: JwtPayload) {
    return this.dashboardService.overview(user);
  }

  @Get('widgets/:size')
  async widgets(
    @CurrentUser() user: JwtPayload,
    @Param('size') size: 'small' | 'medium' | 'large',
  ) {
    const normalized = size === 'small' || size === 'medium' || size === 'large' ? size : 'small';
    return this.dashboardService.widgets(user, normalized);
  }
}
