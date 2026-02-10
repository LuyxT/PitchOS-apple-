import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { JwtPayload } from '../auth/dto/jwt-payload.dto';

@Injectable()
export class WidgetsService {
  constructor(private readonly prisma: PrismaService) {}

  async payload(currentUser: JwtPayload, size: 'small' | 'medium' | 'large') {
    const teamId = currentUser.teamIds[0];

    const [eventsCount, openPayments, unreadMessages, playersCount] = await Promise.all([
      this.prisma.calendarEvent.count({
        where: { teamId, startAt: { gte: new Date() } },
      }),
      this.prisma.monthlyContribution.count({
        where: { teamId, status: { in: ['OPEN', 'OVERDUE'] } },
      }),
      this.prisma.messengerChatMember.aggregate({
        where: { userId: currentUser.sub },
        _sum: { unreadCount: true },
      }),
      this.prisma.player.count({ where: { teamId } }),
    ]);

    const base = {
      teamId,
      generatedAt: new Date().toISOString(),
      cards: {
        events: eventsCount,
        openPayments,
        unreadMessages: unreadMessages._sum.unreadCount ?? 0,
        players: playersCount,
      },
    };

    if (size === 'small') {
      return { ...base, density: 'small' };
    }
    if (size === 'medium') {
      return {
        ...base,
        density: 'medium',
        highlights: [
          `${eventsCount} Termine`,
          `${openPayments} offene Zahlungen`,
        ],
      };
    }
    return {
      ...base,
      density: 'large',
      timeline: await this.loadCashTimeline(teamId),
    };
  }

  private async loadCashTimeline(teamId: string) {
    const tx = await this.prisma.cashTransaction.findMany({
      where: { teamId },
      orderBy: { date: 'asc' },
      take: 60,
    });

    let balance = 0;
    return tx.map((item) => {
      balance += item.type === 'INCOME' ? Number(item.amount) : -Number(item.amount);
      return {
        date: item.date.toISOString(),
        amount: Number(item.amount),
        type: item.type,
        balance,
      };
    });
  }
}
