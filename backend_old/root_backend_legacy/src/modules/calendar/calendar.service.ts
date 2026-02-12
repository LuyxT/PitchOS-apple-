import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { JwtPayload } from '../auth/dto/jwt-payload.dto';
import { CreateCalendarEventDto } from './dto/create-calendar-event.dto';
import { UpdateCalendarEventDto } from './dto/update-calendar-event.dto';

@Injectable()
export class CalendarService {
  constructor(private readonly prisma: PrismaService) {}

  async list(currentUser: JwtPayload, from?: string, to?: string, teamId?: string) {
    const selectedTeams = teamId ? [teamId] : currentUser.teamIds;
    return this.prisma.calendarEvent.findMany({
      where: {
        teamId: { in: selectedTeams },
        startAt: {
          gte: from ? new Date(from) : undefined,
          lte: to ? new Date(to) : undefined,
        },
      },
      orderBy: { startAt: 'asc' },
    });
  }

  async create(currentUser: JwtPayload, input: CreateCalendarEventDto) {
    return this.prisma.calendarEvent.create({
      data: {
        teamId: input.teamId,
        title: input.title,
        description: input.description,
        startAt: new Date(input.startAt),
        endAt: new Date(input.endAt),
        visibility: input.visibility,
        category: input.category,
        eventKind: input.eventKind,
        linkedTrainingPlanId: input.linkedTrainingPlanId,
        playerVisibleGoal: input.playerVisibleGoal,
        playerVisibleDurationMin: input.playerVisibleDurationMin,
        createdBy: currentUser.sub,
      },
    });
  }

  async update(currentUser: JwtPayload, id: string, input: UpdateCalendarEventDto) {
    const existing = await this.prisma.calendarEvent.findUnique({ where: { id } });
    if (!existing || !currentUser.teamIds.includes(existing.teamId)) {
      throw new NotFoundException('Event not found');
    }

    return this.prisma.calendarEvent.update({
      where: { id },
      data: {
        title: input.title,
        description: input.description,
        startAt: input.startAt ? new Date(input.startAt) : undefined,
        endAt: input.endAt ? new Date(input.endAt) : undefined,
        visibility: input.visibility,
        category: input.category,
        eventKind: input.eventKind,
        linkedTrainingPlanId: input.linkedTrainingPlanId,
        playerVisibleGoal: input.playerVisibleGoal,
        playerVisibleDurationMin: input.playerVisibleDurationMin,
      },
    });
  }

  async remove(currentUser: JwtPayload, id: string) {
    const existing = await this.prisma.calendarEvent.findUnique({ where: { id } });
    if (!existing || !currentUser.teamIds.includes(existing.teamId)) {
      throw new NotFoundException('Event not found');
    }

    await this.prisma.calendarEvent.delete({ where: { id } });
    return { success: true };
  }
}
