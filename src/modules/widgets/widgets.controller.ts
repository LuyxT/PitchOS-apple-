import { Controller, Get, Param, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { JwtPayload } from '../auth/dto/jwt-payload.dto';
import { WidgetsService } from './widgets.service';

@ApiTags('widgets')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('widgets')
export class WidgetsController {
  constructor(private readonly widgetsService: WidgetsService) {}

  @Get(':size')
  async bySize(
    @CurrentUser() user: JwtPayload,
    @Param('size') size: 'small' | 'medium' | 'large',
  ) {
    return this.widgetsService.payload(user, size);
  }
}
