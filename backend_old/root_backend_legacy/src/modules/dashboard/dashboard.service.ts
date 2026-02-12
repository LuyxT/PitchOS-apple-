import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { JwtPayload } from '../auth/dto/jwt-payload.dto';

@Injectable()
export class DashboardService {
  constructor(private readonly prisma: PrismaService) {}

  async overview(currentUser: JwtPayload) {
    const teamFilter = { in: currentUser.teamIds };
    const [players, trainings, messages, analysisSessions] = await this.prisma.$transaction([
      this.prisma.player.count({ where: { teamId: teamFilter } }),
      this.prisma.trainingPlan.count({ where: { teamId: teamFilter } }),
      this.prisma.messengerMessage.count({
        where: {
          chat: { teamId: teamFilter },
          createdAt: { gte: new Date(Date.now() - 24 * 60 * 60 * 1000) },
        },
      }),
      this.prisma.analysisSession.count({ where: { teamId: teamFilter } }),
    ]);

    return {
      players,
      trainings,
      messagesLast24h: messages,
      analysisSessions,
      generatedAt: new Date().toISOString(),
    };
  }

  async widgets(currentUser: JwtPayload, size: 'small' | 'medium' | 'large') {
    const data = await this.overview(currentUser);
    if (size === 'small') {
      return {
        size,
        cards: [
          { key: 'players', label: 'Spieler', value: data.players },
          { key: 'trainings', label: 'Trainings', value: data.trainings },
        ],
      };
    }

    if (size === 'medium') {
      return {
        size,
        cards: [
          { key: 'players', label: 'Spieler', value: data.players },
          { key: 'trainings', label: 'Trainings', value: data.trainings },
          { key: 'analysisSessions', label: 'Analysen', value: data.analysisSessions },
        ],
      };
    }

    return {
      size,
      cards: [
        { key: 'players', label: 'Spieler', value: data.players },
        { key: 'trainings', label: 'Trainings', value: data.trainings },
        { key: 'analysisSessions', label: 'Analysen', value: data.analysisSessions },
        { key: 'messagesLast24h', label: 'Nachrichten 24h', value: data.messagesLast24h },
      ],
    };
  }
}
