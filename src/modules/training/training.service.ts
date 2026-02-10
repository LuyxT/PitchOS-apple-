import { Injectable, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { JwtPayload } from '../auth/dto/jwt-payload.dto';
import {
  CreateReportDto,
  CreateTemplateDto,
  CreateTrainingPlanDto,
  LinkCalendarDto,
  UpdateTrainingPlanDto,
} from './dto/training-plan.dto';

@Injectable()
export class TrainingService {
  constructor(private readonly prisma: PrismaService) {}

  async list(currentUser: JwtPayload, teamId?: string) {
    const teams = teamId ? [teamId] : currentUser.teamIds;
    return this.prisma.trainingPlan.findMany({
      where: { teamId: { in: teams } },
      include: {
        phases: {
          include: { exercises: true },
          orderBy: { orderIndex: 'asc' },
        },
        groups: { include: { briefing: true } },
        report: true,
      },
      orderBy: { date: 'desc' },
    });
  }

  async get(currentUser: JwtPayload, id: string) {
    const plan = await this.prisma.trainingPlan.findUnique({
      where: { id },
      include: {
        phases: { include: { exercises: true }, orderBy: { orderIndex: 'asc' } },
        groups: { include: { briefing: true } },
        report: true,
      },
    });
    if (!plan || !currentUser.teamIds.includes(plan.teamId)) {
      throw new NotFoundException('Training plan not found');
    }
    return plan;
  }

  async create(currentUser: JwtPayload, input: CreateTrainingPlanDto) {
    const plan = await this.prisma.$transaction(async (tx) => {
      const created = await tx.trainingPlan.create({
        data: {
          teamId: input.teamId,
          title: input.title,
          date: new Date(input.date),
          location: input.location,
          mainGoal: input.mainGoal,
          secondaryGoals: input.secondaryGoals ?? [],
          status: input.status,
          createdBy: currentUser.sub,
        },
      });

      for (let i = 0; i < input.phases.length; i += 1) {
        const phase = input.phases[i];
        const createdPhase = await tx.trainingPhase.create({
          data: {
            trainingPlanId: created.id,
            orderIndex: i,
            type: phase.type,
            title: phase.title,
            durationMinutes: phase.durationMinutes,
            goal: phase.goal,
            intensity: phase.intensity,
            description: phase.description,
          },
        });

        if (phase.exercises.length) {
          await tx.trainingExercise.createMany({
            data: phase.exercises.map((exercise, idx) => ({
              phaseId: createdPhase.id,
              orderIndex: idx,
              name: exercise.name,
              description: exercise.description,
              durationMinutes: exercise.durationMinutes,
              intensity: exercise.intensity,
              requiredPlayers: exercise.requiredPlayers,
              materials: (exercise.materials ?? {}) as Prisma.InputJsonValue,
              excludedPlayerIds: [],
            })),
          });
        }
      }

      return created;
    });

    return this.get(currentUser, plan.id);
  }

  async update(currentUser: JwtPayload, id: string, input: UpdateTrainingPlanDto) {
    const existing = await this.get(currentUser, id);

    return this.prisma.trainingPlan.update({
      where: { id: existing.id },
      data: {
        title: input.title,
        date: input.date ? new Date(input.date) : undefined,
        location: input.location,
        mainGoal: input.mainGoal,
        secondaryGoals: input.secondaryGoals,
        status: input.status,
      },
    });
  }

  async delete(currentUser: JwtPayload, id: string) {
    await this.get(currentUser, id);
    await this.prisma.trainingPlan.delete({ where: { id } });
    return { success: true };
  }

  async createTemplate(currentUser: JwtPayload, input: CreateTemplateDto) {
    return this.prisma.trainingTemplate.create({
      data: {
        teamId: input.teamId,
        name: input.name,
        payload: input.payload as Prisma.InputJsonValue,
        createdBy: currentUser.sub,
      },
    });
  }

  async listTemplates(currentUser: JwtPayload, teamId?: string, query?: string) {
    const teams = teamId ? [teamId] : currentUser.teamIds;
    return this.prisma.trainingTemplate.findMany({
      where: {
        teamId: { in: teams },
        name: query ? { contains: query, mode: 'insensitive' } : undefined,
      },
      orderBy: { updatedAt: 'desc' },
    });
  }

  async duplicate(currentUser: JwtPayload, planId: string, name?: string) {
    const source = await this.get(currentUser, planId);
    const clone = await this.prisma.trainingPlan.create({
      data: {
        teamId: source.teamId,
        title: name ?? `${source.title} Kopie`,
        date: source.date,
        location: source.location,
        mainGoal: source.mainGoal,
        secondaryGoals: source.secondaryGoals,
        status: 'DRAFT',
        createdBy: currentUser.sub,
      },
    });

    const phases = source.phases;
    for (const phase of phases) {
      const createdPhase = await this.prisma.trainingPhase.create({
        data: {
          trainingPlanId: clone.id,
          orderIndex: phase.orderIndex,
          type: phase.type,
          title: phase.title,
          durationMinutes: phase.durationMinutes,
          goal: phase.goal,
          intensity: phase.intensity,
          description: phase.description ?? undefined,
        },
      });

      if (phase.exercises.length) {
        await this.prisma.trainingExercise.createMany({
          data: phase.exercises.map((exercise) => ({
            phaseId: createdPhase.id,
            orderIndex: exercise.orderIndex,
            name: exercise.name,
            description: exercise.description ?? undefined,
            durationMinutes: exercise.durationMinutes,
            intensity: exercise.intensity,
            requiredPlayers: exercise.requiredPlayers,
            materials: (exercise.materials ?? {}) as Prisma.InputJsonValue,
            excludedPlayerIds: exercise.excludedPlayerIds,
          })),
        });
      }
    }

    return this.get(currentUser, clone.id);
  }

  async startLive(currentUser: JwtPayload, planId: string) {
    await this.get(currentUser, planId);
    return this.prisma.trainingPlan.update({
      where: { id: planId },
      data: { status: 'LIVE' },
    });
  }

  async updateLive(currentUser: JwtPayload, planId: string, payload: Record<string, unknown>) {
    await this.get(currentUser, planId);
    return this.prisma.trainingDeviation.create({
      data: {
        trainingPlanId: planId,
        kind: String(payload.kind ?? 'timeAdjusted'),
        plannedValue: payload.plannedValue ? String(payload.plannedValue) : undefined,
        actualValue: payload.actualValue ? String(payload.actualValue) : undefined,
        note: payload.note ? String(payload.note) : undefined,
        phaseId: payload.phaseId ? String(payload.phaseId) : undefined,
        exerciseId: payload.exerciseId ? String(payload.exerciseId) : undefined,
      },
    });
  }

  async createReport(currentUser: JwtPayload, planId: string, input: CreateReportDto) {
    await this.get(currentUser, planId);
    return this.prisma.trainingReport.upsert({
      where: { trainingPlanId: planId },
      create: {
        trainingPlanId: planId,
        plannedTotalMin: input.plannedTotalMin,
        actualTotalMin: input.actualTotalMin,
        attendance: input.attendance as Prisma.InputJsonValue,
        groupFeedback: input.groupFeedback as Prisma.InputJsonValue,
        playerNotes: input.playerNotes as Prisma.InputJsonValue,
        summary: input.summary,
      },
      update: {
        plannedTotalMin: input.plannedTotalMin,
        actualTotalMin: input.actualTotalMin,
        attendance: input.attendance as Prisma.InputJsonValue,
        groupFeedback: input.groupFeedback as Prisma.InputJsonValue,
        playerNotes: input.playerNotes as Prisma.InputJsonValue,
        summary: input.summary,
      },
    });
  }

  async getReport(currentUser: JwtPayload, planId: string) {
    await this.get(currentUser, planId);
    return this.prisma.trainingReport.findUnique({ where: { trainingPlanId: planId } });
  }

  async linkCalendar(currentUser: JwtPayload, planId: string, input: LinkCalendarDto) {
    const plan = await this.get(currentUser, planId);
    const event = await this.prisma.calendarEvent.create({
      data: {
        teamId: input.teamId,
        title: input.title,
        startAt: new Date(input.startAt),
        endAt: new Date(input.endAt),
        eventKind: 'TRAINING',
        linkedTrainingPlanId: plan.id,
        playerVisibleGoal: input.playerVisibleGoal,
        playerVisibleDurationMin: input.playerVisibleDurationMin,
        createdBy: currentUser.sub,
      },
    });

    await this.prisma.trainingPlan.update({
      where: { id: planId },
      data: { calendarEventId: event.id },
    });

    return event;
  }
}
