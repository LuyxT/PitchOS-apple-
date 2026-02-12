import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { FinanceEntryType, Prisma } from '@prisma/client';
import { ERROR_CODES } from '../common/constants/error-codes';
import { PrismaService } from '../prisma/prisma.service';
import { CreateFinanceEntryDto } from './dto/create-finance-entry.dto';

@Injectable()
export class FinanceService {
  constructor(private readonly prisma: PrismaService) {}

  async bootstrap(
    userId: string,
    clubId?: string,
  ): Promise<Record<string, unknown>> {
    const resolvedClubId = await this.resolveClubIdForRead(userId, clubId);

    if (!resolvedClubId) {
      return {
        clubId: null,
        entries: [],
        summary: {
          income: 0,
          expense: 0,
          balance: 0,
        },
      };
    }

    const entries = await this.prisma.financeEntry.findMany({
      where: { clubId: resolvedClubId },
      orderBy: { date: 'desc' },
    });

    const mappedEntries = entries.map((entry) => this.mapEntry(entry));

    const income = mappedEntries
      .filter((entry) => entry.type === FinanceEntryType.INCOME)
      .reduce((sum, entry) => sum + entry.amount, 0);

    const expense = mappedEntries
      .filter((entry) => entry.type === FinanceEntryType.EXPENSE)
      .reduce((sum, entry) => sum + entry.amount, 0);

    return {
      clubId: resolvedClubId,
      entries: mappedEntries,
      summary: {
        income,
        expense,
        balance: income - expense,
      },
    };
  }

  async createEntry(
    userId: string,
    dto: CreateFinanceEntryDto,
  ): Promise<Record<string, unknown>> {
    const resolvedClubId = await this.resolveClubIdForWrite(userId, dto.clubId);

    const entry = await this.prisma.financeEntry.create({
      data: {
        clubId: resolvedClubId,
        amount: new Prisma.Decimal(dto.amount),
        type: dto.type,
        title: dto.title.trim(),
        date: new Date(dto.date),
      },
    });

    return this.mapEntry(entry);
  }

  async listEntries(
    userId: string,
    clubId?: string,
  ): Promise<Array<Record<string, unknown>>> {
    const resolvedClubId = await this.resolveClubIdForRead(userId, clubId);

    if (!resolvedClubId) {
      return [];
    }

    const entries = await this.prisma.financeEntry.findMany({
      where: { clubId: resolvedClubId },
      orderBy: { date: 'desc' },
    });

    return entries.map((entry) => this.mapEntry(entry));
  }

  private async resolveClubIdForRead(
    userId: string,
    clubId?: string,
  ): Promise<string | null> {
    if (clubId) {
      const club = await this.prisma.club.findUnique({ where: { id: clubId } });
      if (!club) {
        throw new NotFoundException({
          code: ERROR_CODES.notFound,
          message: 'Club not found.',
        });
      }

      return clubId;
    }

    const user = await this.prisma.user.findUnique({ where: { id: userId } });

    if (!user) {
      throw new NotFoundException({
        code: ERROR_CODES.notFound,
        message: 'User not found.',
      });
    }

    return user.clubId;
  }

  private async resolveClubIdForWrite(
    userId: string,
    clubId?: string,
  ): Promise<string> {
    const resolvedClubId = await this.resolveClubIdForRead(userId, clubId);

    if (!resolvedClubId) {
      throw new BadRequestException({
        code: ERROR_CODES.badRequest,
        message: 'Club is required to create finance entries.',
      });
    }

    return resolvedClubId;
  }

  private mapEntry(entry: {
    id: string;
    clubId: string;
    amount: Prisma.Decimal;
    type: FinanceEntryType;
    title: string;
    date: Date;
    createdAt: Date;
    updatedAt: Date;
  }) {
    return {
      id: entry.id,
      clubId: entry.clubId,
      amount: Number(entry.amount),
      type: entry.type,
      title: entry.title,
      date: entry.date,
      createdAt: entry.createdAt,
      updatedAt: entry.updatedAt,
    };
  }
}
