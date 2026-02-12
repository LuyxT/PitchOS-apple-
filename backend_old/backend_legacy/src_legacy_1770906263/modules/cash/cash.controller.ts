import { Body, Controller, Delete, Get, Param, Patch, Post, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { JwtPayload } from '../auth/dto/jwt-payload.dto';
import {
  CreateCashGoalDto,
  CreateMonthlyContributionDto,
  CreateTransactionDto,
  UpdateTransactionDto,
} from './dto/cash.dto';
import { CashService } from './cash.service';

@ApiTags('cash')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('cash')
export class CashController {
  constructor(private readonly cashService: CashService) {}

  @Get('dashboard')
  async dashboard(
    @CurrentUser() user: JwtPayload,
    @Query('teamId') teamId: string,
    @Query('from') from?: string,
    @Query('to') to?: string,
  ) {
    return this.cashService.dashboard(user, teamId, from, to);
  }

  @Get('transactions')
  async transactions(
    @CurrentUser() user: JwtPayload,
    @Query('teamId') teamId: string,
    @Query('q') q?: string,
  ) {
    return this.cashService.listTransactions(user, teamId, q);
  }

  @Post('transactions')
  async createTransaction(@CurrentUser() user: JwtPayload, @Body() body: CreateTransactionDto) {
    return this.cashService.createTransaction(user, body);
  }

  @Patch('transactions/:id')
  async updateTransaction(
    @CurrentUser() user: JwtPayload,
    @Param('id') id: string,
    @Body() body: UpdateTransactionDto,
  ) {
    return this.cashService.updateTransaction(user, id, body);
  }

  @Delete('transactions/:id')
  async deleteTransaction(@CurrentUser() user: JwtPayload, @Param('id') id: string) {
    return this.cashService.deleteTransaction(user, id);
  }

  @Get('monthly-contributions')
  async monthly(@CurrentUser() user: JwtPayload, @Query('teamId') teamId: string) {
    return this.cashService.listMonthlyContributions(user, teamId);
  }

  @Post('monthly-contributions')
  async createMonthly(
    @CurrentUser() user: JwtPayload,
    @Body() body: CreateMonthlyContributionDto,
  ) {
    return this.cashService.createMonthlyContribution(user, body);
  }

  @Patch('monthly-contributions/:id/status')
  async updateMonthlyStatus(
    @CurrentUser() user: JwtPayload,
    @Param('id') id: string,
    @Body('status') status: 'PAID' | 'OPEN' | 'OVERDUE',
  ) {
    return this.cashService.updateMonthlyStatus(user, id, status);
  }

  @Get('goals')
  async goals(@CurrentUser() user: JwtPayload, @Query('teamId') teamId: string) {
    return this.cashService.listGoals(user, teamId);
  }

  @Post('goals')
  async createGoal(@CurrentUser() user: JwtPayload, @Body() body: CreateCashGoalDto) {
    return this.cashService.createGoal(user, body);
  }
}
