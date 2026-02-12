import { Body, Controller, Get, Post, Query } from '@nestjs/common';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { AuthenticatedUser } from '../common/interfaces/request-context.interface';
import { CreateFinanceEntryDto } from './dto/create-finance-entry.dto';
import { ListFinanceEntriesDto } from './dto/list-finance-entries.dto';
import { FinanceService } from './finance.service';

@Controller('finance')
export class FinanceController {
  constructor(private readonly financeService: FinanceService) {}

  @Get('bootstrap')
  async bootstrap(
    @CurrentUser() user: AuthenticatedUser,
    @Query() query: ListFinanceEntriesDto,
  ) {
    return this.financeService.bootstrap(user.id, query.clubId);
  }

  @Get('cash/bootstrap')
  async bootstrapCompat(
    @CurrentUser() user: AuthenticatedUser,
    @Query() query: ListFinanceEntriesDto,
  ) {
    return this.financeService.bootstrap(user.id, query.clubId);
  }

  @Post('entry')
  async createEntry(
    @CurrentUser() user: AuthenticatedUser,
    @Body() dto: CreateFinanceEntryDto,
  ) {
    return this.financeService.createEntry(user.id, dto);
  }

  @Get('entries')
  async listEntries(
    @CurrentUser() user: AuthenticatedUser,
    @Query() query: ListFinanceEntriesDto,
  ) {
    return this.financeService.listEntries(user.id, query.clubId);
  }
}
