import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { JwtPayload } from '../auth/dto/jwt-payload.dto';
import {
  CreateCashGoalDto,
  CreateMonthlyContributionDto,
  CreateTransactionDto,
  UpdateTransactionDto,
} from './dto/cash.dto';

@Injectable()
export class CashService {
  constructor(private readonly prisma: PrismaService) {}

  async dashboard(currentUser: JwtPayload, teamId: string, from?: string, to?: string) {
    this.ensureTeamAccess(currentUser, teamId);

    const where = {
      teamId,
      date: {
        gte: from ? new Date(from) : undefined,
        lte: to ? new Date(to) : undefined,
      },
    };

    const transactions = await this.prisma.cashTransaction.findMany({ where });

    const income = transactions
      .filter((entry) => entry.type === 'INCOME')
      .reduce((sum, entry) => sum + Number(entry.amount), 0);
    const expenses = transactions
      .filter((entry) => entry.type === 'EXPENSE')
      .reduce((sum, entry) => sum + Number(entry.amount), 0);

    const openMonthly = await this.prisma.monthlyContribution.findMany({
      where: { teamId, status: { in: ['OPEN', 'OVERDUE'] } },
    });
    const openAmount = openMonthly.reduce((sum, item) => sum + Number(item.amount), 0);

    const balance = income - expenses;

    return {
      balance,
      income,
      expenses,
      projectedBalance: balance + openAmount,
      openAmount,
      transactionCount: transactions.length,
    };
  }

  async listTransactions(currentUser: JwtPayload, teamId: string, query?: string) {
    this.ensureTeamAccess(currentUser, teamId);

    return this.prisma.cashTransaction.findMany({
      where: {
        teamId,
        OR: query
          ? [
              { category: { contains: query, mode: 'insensitive' } },
              { description: { contains: query, mode: 'insensitive' } },
              { comment: { contains: query, mode: 'insensitive' } },
            ]
          : undefined,
      },
      orderBy: { date: 'desc' },
    });
  }

  async createTransaction(currentUser: JwtPayload, input: CreateTransactionDto) {
    this.ensureTeamAccess(currentUser, input.teamId);

    return this.prisma.cashTransaction.create({
      data: {
        teamId: input.teamId,
        amount: input.amount,
        date: new Date(input.date),
        category: input.category,
        description: input.description,
        type: input.type,
        playerId: input.playerId,
        responsibleUserId: currentUser.sub,
        comment: input.comment,
        paymentStatus: input.paymentStatus,
      },
    });
  }

  async updateTransaction(currentUser: JwtPayload, id: string, input: UpdateTransactionDto) {
    const existing = await this.prisma.cashTransaction.findUnique({ where: { id } });
    if (!existing) {
      throw new NotFoundException('Transaktion nicht gefunden');
    }

    this.ensureTeamAccess(currentUser, existing.teamId);

    return this.prisma.cashTransaction.update({
      where: { id },
      data: {
        amount: input.amount,
        date: input.date ? new Date(input.date) : undefined,
        category: input.category,
        description: input.description,
        type: input.type,
        playerId: input.playerId,
        comment: input.comment,
        paymentStatus: input.paymentStatus,
      },
    });
  }

  async deleteTransaction(currentUser: JwtPayload, id: string) {
    const existing = await this.prisma.cashTransaction.findUnique({ where: { id } });
    if (!existing) {
      throw new NotFoundException('Transaktion nicht gefunden');
    }

    this.ensureTeamAccess(currentUser, existing.teamId);

    await this.prisma.cashTransaction.delete({ where: { id } });
    return { success: true };
  }

  async listMonthlyContributions(currentUser: JwtPayload, teamId: string) {
    this.ensureTeamAccess(currentUser, teamId);
    return this.prisma.monthlyContribution.findMany({
      where: { teamId },
      orderBy: { dueDate: 'asc' },
    });
  }

  async createMonthlyContribution(currentUser: JwtPayload, input: CreateMonthlyContributionDto) {
    this.ensureTeamAccess(currentUser, input.teamId);

    return this.prisma.monthlyContribution.create({
      data: {
        teamId: input.teamId,
        playerId: input.playerId,
        amount: input.amount,
        dueDate: new Date(input.dueDate),
        status: input.status,
      },
    });
  }

  async updateMonthlyStatus(currentUser: JwtPayload, id: string, status: 'PAID' | 'OPEN' | 'OVERDUE') {
    const existing = await this.prisma.monthlyContribution.findUnique({ where: { id } });
    if (!existing) {
      throw new NotFoundException('Monatsbeitrag nicht gefunden');
    }

    this.ensureTeamAccess(currentUser, existing.teamId);

    return this.prisma.monthlyContribution.update({
      where: { id },
      data: {
        status,
        paidAt: status === 'PAID' ? new Date() : null,
      },
    });
  }

  async listGoals(currentUser: JwtPayload, teamId: string) {
    this.ensureTeamAccess(currentUser, teamId);
    return this.prisma.cashGoal.findMany({
      where: { teamId },
      orderBy: { endDate: 'asc' },
    });
  }

  async createGoal(currentUser: JwtPayload, input: CreateCashGoalDto) {
    this.ensureTeamAccess(currentUser, input.teamId);

    return this.prisma.cashGoal.create({
      data: {
        teamId: input.teamId,
        name: input.name,
        targetAmount: input.targetAmount,
        currentProgress: 0,
        startDate: new Date(input.startDate),
        endDate: new Date(input.endDate),
      },
    });
  }

  private ensureTeamAccess(currentUser: JwtPayload, teamId: string): void {
    if (!currentUser.teamIds.includes(teamId)) {
      throw new NotFoundException('Team nicht gefunden');
    }
  }
}
