import {
  Body,
  Controller,
  Delete,
  Get,
  HttpException,
  Param,
  Post,
  Put,
  Query,
} from '@nestjs/common';
import { randomUUID } from 'crypto';

type Json = Record<string, any>;

@Controller()
export class AppController {
  private readonly trainingPlans: Json[] = [];
  private readonly trainingPhasesByPlan = new Map<string, Json[]>();
  private readonly trainingExercisesByPlan = new Map<string, Json[]>();
  private readonly trainingGroupsByPlan = new Map<string, Json[]>();
  private readonly trainingBriefingsByGroup = new Map<string, Json>();
  private readonly trainingAvailabilityByPlan = new Map<string, Json[]>();
  private readonly trainingDeviationsByPlan = new Map<string, Json[]>();
  private readonly trainingReportsByPlan = new Map<string, Json>();
  private readonly trainingTemplates: Json[] = [];

  private readonly defaultCalendarCategoryId = randomUUID();

  constructor() {
    this.trainingTemplates.push({
      id: randomUUID(),
      name: 'Passdreieck',
      baseDescription: 'Technik und Orientierung mit hoher Wiederholungszahl.',
      defaultDuration: 12,
      defaultIntensity: 'medium',
      defaultRequiredPlayers: 8,
      defaultMaterials: [
        { kind: 'baelle', label: 'Bälle', quantity: 8 },
        { kind: 'huetchen', label: 'Hütchen', quantity: 12 },
      ],
    });
  }

  @Get('bootstrap')
  bootstrap() {
    console.log('[bootstrap] endpoint called');
    return {
      status: 'ok',
      service: 'pitchinsights-backend',
      version: '1.0.0',
      time: new Date().toISOString(),
    };
  }

  @Get()
  root() {
    return { status: 'ok', service: 'pitchinsights-backend' };
  }

  @Get('health')
  health() {
    return { status: 'ok' };
  }

  @Get('training/plans')
  listTrainingPlans(@Query('limit') limitQuery?: string) {
    const limit = Number(limitQuery ?? 80);
    const items = [...this.trainingPlans]
      .sort((a, b) => (a.date < b.date ? 1 : -1))
      .slice(0, Number.isFinite(limit) && limit > 0 ? limit : 80);

    return { items, nextCursor: null };
  }

  @Get('training/plans/:id')
  getTrainingPlan(@Param('id') id: string) {
    return this.buildTrainingEnvelope(id);
  }

  @Post('training/plans')
  createTrainingPlan(@Body() body: Json) {
    const now = new Date().toISOString();
    const created = {
      id: randomUUID(),
      title: String(body?.title ?? '').trim() || 'Training',
      date: this.toISO(body?.date) ?? now,
      location: String(body?.location ?? ''),
      mainGoal: String(body?.mainGoal ?? ''),
      secondaryGoals: Array.isArray(body?.secondaryGoals) ? body.secondaryGoals.map(String) : [],
      status: String(body?.status ?? 'draft').toLowerCase(),
      linkedMatchID: body?.linkedMatchID ?? null,
      calendarEventID: null,
      createdAt: now,
      updatedAt: now,
    };

    this.trainingPlans.push(created);
    this.trainingPhasesByPlan.set(created.id, []);
    this.trainingExercisesByPlan.set(created.id, []);
    this.trainingGroupsByPlan.set(created.id, []);
    this.trainingAvailabilityByPlan.set(created.id, []);
    this.trainingDeviationsByPlan.set(created.id, []);

    return created;
  }

  @Put('training/plans/:id')
  updateTrainingPlan(@Param('id') id: string, @Body() body: Json) {
    const plan = this.requirePlan(id);

    plan.title = String(body?.title ?? plan.title);
    plan.date = this.toISO(body?.date) ?? plan.date;
    plan.location = String(body?.location ?? plan.location ?? '');
    plan.mainGoal = String(body?.mainGoal ?? plan.mainGoal ?? '');
    plan.secondaryGoals = Array.isArray(body?.secondaryGoals)
      ? body.secondaryGoals.map(String)
      : plan.secondaryGoals;
    plan.status = String(body?.status ?? plan.status ?? 'draft').toLowerCase();
    plan.linkedMatchID = body?.linkedMatchID ?? null;
    plan.updatedAt = new Date().toISOString();

    return plan;
  }

  @Delete('training/plans/:id')
  deleteTrainingPlan(@Param('id') id: string) {
    const index = this.trainingPlans.findIndex((item) => item.id === id);
    if (index < 0) {
      throw new HttpException('Training plan not found', 404);
    }

    this.trainingPlans.splice(index, 1);
    this.trainingPhasesByPlan.delete(id);
    this.trainingExercisesByPlan.delete(id);
    this.trainingGroupsByPlan.delete(id);
    this.trainingAvailabilityByPlan.delete(id);
    this.trainingDeviationsByPlan.delete(id);
    this.trainingReportsByPlan.delete(id);

    return {};
  }

  @Put('training/plans/:id/phases')
  saveTrainingPhases(@Param('id') id: string, @Body() body: Json) {
    this.requirePlan(id);

    const phases: Json[] = Array.isArray(body?.phases)
      ? body.phases.map((phase: Json, index: number) => ({
          id: String(phase?.id ?? randomUUID()),
          planID: id,
          orderIndex: Number.isFinite(Number(phase?.orderIndex)) ? Number(phase.orderIndex) : index,
          type: String(phase?.type ?? 'main'),
          title: String(phase?.title ?? 'Phase'),
          durationMinutes: Math.max(1, Number(phase?.durationMinutes ?? 10)),
          goal: String(phase?.goal ?? ''),
          intensity: String(phase?.intensity ?? 'medium'),
          description: String(phase?.description ?? ''),
          isCompletedLive: Boolean(phase?.isCompletedLive ?? false),
        }))
      : [];

    this.trainingPhasesByPlan.set(id, phases);

    const currentExercises = this.trainingExercisesByPlan.get(id) ?? [];
    const phaseIDSet = new Set(phases.map((item) => item.id));
    this.trainingExercisesByPlan.set(
      id,
      currentExercises.filter((exercise) => phaseIDSet.has(exercise.phaseID)),
    );

    return phases;
  }

  @Put('training/plans/:id/exercises')
  saveTrainingExercises(@Param('id') id: string, @Body() body: Json) {
    this.requirePlan(id);

    const knownPhases = this.trainingPhasesByPlan.get(id) ?? [];
    const phaseIDSet = new Set(knownPhases.map((item) => item.id));

    const exercises: Json[] = Array.isArray(body?.exercises)
      ? body.exercises
          .filter((exercise: Json) => phaseIDSet.has(String(exercise?.phaseID ?? '')))
          .map((exercise: Json, index: number) => ({
            id: String(exercise?.id ?? randomUUID()),
            phaseID: String(exercise?.phaseID),
            orderIndex: Number.isFinite(Number(exercise?.orderIndex)) ? Number(exercise.orderIndex) : index,
            name: String(exercise?.name ?? 'Übung'),
            description: String(exercise?.description ?? ''),
            durationMinutes: Math.max(1, Number(exercise?.durationMinutes ?? 10)),
            intensity: String(exercise?.intensity ?? 'medium'),
            requiredPlayers: Math.max(1, Number(exercise?.requiredPlayers ?? 1)),
            materials: Array.isArray(exercise?.materials)
              ? exercise.materials.map((material: Json) => ({
                  kind: String(material?.kind ?? 'sonstiges'),
                  label: String(material?.label ?? ''),
                  quantity: Math.max(0, Number(material?.quantity ?? 0)),
                }))
              : [],
            excludedPlayerIDs: Array.isArray(exercise?.excludedPlayerIDs)
              ? exercise.excludedPlayerIDs
              : [],
            templateSourceID: exercise?.templateSourceID ?? null,
            isSkippedLive: Boolean(exercise?.isSkippedLive ?? false),
            actualDurationMinutes:
              exercise?.actualDurationMinutes == null
                ? null
                : Math.max(1, Number(exercise.actualDurationMinutes)),
          }))
      : [];

    this.trainingExercisesByPlan.set(id, exercises);
    return exercises;
  }

  @Post('training/templates')
  createTrainingTemplate(@Body() body: Json) {
    const template = {
      id: randomUUID(),
      name: String(body?.name ?? '').trim() || 'Neue Vorlage',
      baseDescription: String(body?.baseDescription ?? ''),
      defaultDuration: Math.max(1, Number(body?.defaultDuration ?? 10)),
      defaultIntensity: String(body?.defaultIntensity ?? 'medium'),
      defaultRequiredPlayers: Math.max(1, Number(body?.defaultRequiredPlayers ?? 1)),
      defaultMaterials: Array.isArray(body?.defaultMaterials)
        ? body.defaultMaterials.map((material: Json) => ({
            kind: String(material?.kind ?? 'sonstiges'),
            label: String(material?.label ?? ''),
            quantity: Math.max(0, Number(material?.quantity ?? 0)),
          }))
        : [],
    };

    this.trainingTemplates.unshift(template);
    return template;
  }

  @Get('training/templates')
  listTrainingTemplates(
    @Query('query') query?: string,
    @Query('limit') limitQuery?: string,
  ) {
    const needle = String(query ?? '').trim().toLowerCase();
    const limit = Number(limitQuery ?? 120);

    const filtered = this.trainingTemplates.filter((item) =>
      needle.length === 0
        ? true
        : item.name.toLowerCase().includes(needle) || item.baseDescription.toLowerCase().includes(needle),
    );

    return {
      items: filtered.slice(0, Number.isFinite(limit) && limit > 0 ? limit : 120),
      nextCursor: null,
    };
  }

  @Post('training/plans/:id/groups')
  createTrainingGroup(@Param('id') id: string, @Body() body: Json) {
    this.requirePlan(id);

    const groups = this.trainingGroupsByPlan.get(id) ?? [];
    const created = {
      id: String(body?.id ?? randomUUID()),
      planID: id,
      name: String(body?.name ?? 'Gruppe'),
      goal: String(body?.goal ?? ''),
      playerIDs: Array.isArray(body?.playerIDs) ? body.playerIDs : [],
      headCoachUserID: String(body?.headCoachUserID ?? 'coach.default'),
      assistantCoachUserID: body?.assistantCoachUserID ?? null,
    };

    groups.push(created);
    this.trainingGroupsByPlan.set(id, groups);
    return created;
  }

  @Put('training/groups/:id')
  updateTrainingGroup(@Param('id') groupID: string, @Body() body: Json) {
    const { planID, group } = this.requireGroup(groupID);

    group.name = String(body?.name ?? group.name);
    group.goal = String(body?.goal ?? group.goal ?? '');
    group.playerIDs = Array.isArray(body?.playerIDs) ? body.playerIDs : group.playerIDs;
    group.headCoachUserID = String(body?.headCoachUserID ?? group.headCoachUserID ?? 'coach.default');
    group.assistantCoachUserID = body?.assistantCoachUserID ?? null;

    this.trainingGroupsByPlan.set(planID, this.trainingGroupsByPlan.get(planID) ?? []);
    return group;
  }

  @Put('training/groups/:id/briefing')
  saveTrainingGroupBriefing(@Param('id') groupID: string, @Body() body: Json) {
    this.requireGroup(groupID);

    const briefing = {
      id: this.trainingBriefingsByGroup.get(groupID)?.id ?? randomUUID(),
      groupID,
      goal: String(body?.goal ?? ''),
      coachingPoints: String(body?.coachingPoints ?? ''),
      focusPoints: String(body?.focusPoints ?? ''),
      commonMistakes: String(body?.commonMistakes ?? ''),
      targetIntensity: String(body?.targetIntensity ?? 'medium'),
    };

    this.trainingBriefingsByGroup.set(groupID, briefing);
    return briefing;
  }

  @Put('training/plans/:id/participants')
  assignTrainingParticipants(@Param('id') id: string, @Body() body: Json) {
    this.requirePlan(id);

    const availability: Json[] = Array.isArray(body?.availability)
      ? body.availability.map((entry: Json) => ({
          playerID: entry?.playerID,
          availability: String(entry?.availability ?? 'fit'),
          isAbsent: Boolean(entry?.isAbsent ?? false),
          isLimited: Boolean(entry?.isLimited ?? false),
          note: String(entry?.note ?? ''),
        }))
      : [];

    this.trainingAvailabilityByPlan.set(id, availability);
    return availability;
  }

  @Post('training/plans/:id/live/start')
  startTrainingLive(@Param('id') id: string) {
    const plan = this.requirePlan(id);
    plan.status = 'live';
    plan.updatedAt = new Date().toISOString();
    return plan;
  }

  @Put('training/plans/:id/live/state')
  saveTrainingLiveState(@Param('id') id: string, @Body() body: Json) {
    this.requirePlan(id);

    if (Array.isArray(body?.phases)) {
      this.saveTrainingPhases(id, { phases: body.phases });
    }
    if (Array.isArray(body?.exercises)) {
      this.saveTrainingExercises(id, { exercises: body.exercises });
    }

    return this.buildTrainingEnvelope(id);
  }

  @Post('training/plans/:id/live/deviations')
  createTrainingLiveDeviation(@Param('id') id: string, @Body() body: Json) {
    this.requirePlan(id);

    const item = {
      id: randomUUID(),
      planID: id,
      phaseID: body?.phaseID ?? null,
      exerciseID: body?.exerciseID ?? null,
      kind: String(body?.kind ?? 'timeAdjusted'),
      plannedValue: String(body?.plannedValue ?? ''),
      actualValue: String(body?.actualValue ?? ''),
      note: String(body?.note ?? ''),
      timestamp: this.toISO(body?.timestamp) ?? new Date().toISOString(),
    };

    const list = this.trainingDeviationsByPlan.get(id) ?? [];
    list.push(item);
    this.trainingDeviationsByPlan.set(id, list);

    return item;
  }

  @Post('training/plans/:id/report')
  createTrainingReport(@Param('id') id: string, @Body() body: Json) {
    this.requirePlan(id);

    const report = {
      id: this.trainingReportsByPlan.get(id)?.id ?? randomUUID(),
      planID: id,
      generatedAt: new Date().toISOString(),
      plannedTotalMinutes: Math.max(0, Number(body?.plannedTotalMinutes ?? 0)),
      actualTotalMinutes: Math.max(0, Number(body?.actualTotalMinutes ?? 0)),
      attendance: Array.isArray(body?.attendance) ? body.attendance : [],
      groupFeedback: Array.isArray(body?.groupFeedback) ? body.groupFeedback : [],
      playerNotes: Array.isArray(body?.playerNotes) ? body.playerNotes : [],
      summary: String(body?.summary ?? ''),
    };

    this.trainingReportsByPlan.set(id, report);
    return report;
  }

  @Get('training/plans/:id/report')
  getTrainingReport(@Param('id') id: string) {
    this.requirePlan(id);
    const report = this.trainingReportsByPlan.get(id);
    if (!report) {
      throw new HttpException('Training report not found', 404);
    }
    return report;
  }

  @Post('training/plans/:id/calendar-link')
  linkTrainingToCalendar(@Param('id') id: string, @Body() body: Json) {
    const plan = this.requirePlan(id);
    const now = new Date();
    const startDate = now.toISOString();
    const endDate = new Date(now.getTime() + 90 * 60 * 1000).toISOString();

    const event = {
      id: randomUUID(),
      title: plan.title,
      startDate,
      endDate,
      categoryId: this.defaultCalendarCategoryId,
      visibility: 'team',
      audience: 'team',
      audiencePlayerIds: [],
      recurrence: 'none',
      location: plan.location,
      notes: '',
      linkedTrainingPlanID: id,
      eventKind: 'training',
      playerVisibleGoal:
        String(body?.playersViewLevel ?? 'basic') === 'basicPlusGoalDuration' ? plan.mainGoal : null,
      playerVisibleDurationMinutes: 90,
    };

    plan.calendarEventID = event.id;
    plan.updatedAt = new Date().toISOString();
    return event;
  }

  @Post('training/plans/:id/duplicate')
  duplicateTrainingPlan(@Param('id') id: string, @Body() body: Json) {
    const source = this.requirePlan(id);
    const now = new Date().toISOString();

    const copy = {
      ...source,
      id: randomUUID(),
      title: String(body?.name ?? `${source.title} Kopie`),
      date: this.toISO(body?.targetDate) ?? source.date,
      status: 'draft',
      calendarEventID: null,
      createdAt: now,
      updatedAt: now,
    };

    this.trainingPlans.push(copy);

    const sourcePhases = this.trainingPhasesByPlan.get(id) ?? [];
    const copiedPhases = sourcePhases.map((phase) => ({
      ...phase,
      id: randomUUID(),
      planID: copy.id,
    }));
    this.trainingPhasesByPlan.set(copy.id, copiedPhases);

    const phaseMap = new Map(sourcePhases.map((phase, idx) => [phase.id, copiedPhases[idx]?.id]));
    const sourceExercises = this.trainingExercisesByPlan.get(id) ?? [];
    const copiedExercises = sourceExercises
      .map((exercise) => ({
        ...exercise,
        id: randomUUID(),
        phaseID: phaseMap.get(exercise.phaseID) ?? exercise.phaseID,
      }))
      .filter((exercise) => copiedPhases.some((phase) => phase.id === exercise.phaseID));

    this.trainingExercisesByPlan.set(copy.id, copiedExercises);

    const sourceGroups = this.trainingGroupsByPlan.get(id) ?? [];
    const copiedGroups = sourceGroups.map((group) => ({ ...group, id: randomUUID(), planID: copy.id }));
    this.trainingGroupsByPlan.set(copy.id, copiedGroups);

    const sourceAvailability = this.trainingAvailabilityByPlan.get(id) ?? [];
    this.trainingAvailabilityByPlan.set(copy.id, [...sourceAvailability]);

    const sourceDeviations = this.trainingDeviationsByPlan.get(id) ?? [];
    this.trainingDeviationsByPlan.set(
      copy.id,
      sourceDeviations.map((item) => ({ ...item, id: randomUUID(), planID: copy.id })),
    );

    return copy;
  }

  @Get('trainings')
  trainingsList() {
    return this.trainingPlans.map((plan) => ({
      title: plan.title,
      date: plan.date,
      focus: plan.mainGoal,
    }));
  }

  private buildTrainingEnvelope(planID: string) {
    const plan = this.requirePlan(planID);
    const phases = this.trainingPhasesByPlan.get(planID) ?? [];
    const exercises = this.trainingExercisesByPlan.get(planID) ?? [];
    const groups = this.trainingGroupsByPlan.get(planID) ?? [];
    const briefings = groups
      .map((group) => this.trainingBriefingsByGroup.get(group.id))
      .filter((item): item is Json => Boolean(item));
    const availability = this.trainingAvailabilityByPlan.get(planID) ?? [];
    const deviations = this.trainingDeviationsByPlan.get(planID) ?? [];
    const report = this.trainingReportsByPlan.get(planID) ?? null;

    return {
      plan,
      phases,
      exercises,
      groups,
      briefings,
      report,
      availability,
      deviations,
    };
  }

  private requirePlan(id: string) {
    const plan = this.trainingPlans.find((item) => item.id === id);
    if (!plan) {
      throw new HttpException('Training plan not found', 404);
    }
    return plan;
  }

  private requireGroup(groupID: string) {
    for (const [planID, groups] of this.trainingGroupsByPlan.entries()) {
      const group = groups.find((item) => item.id === groupID);
      if (group) {
        return { planID, group };
      }
    }
    throw new HttpException('Training group not found', 404);
  }

  private toISO(value: unknown): string | null {
    if (typeof value !== 'string' || value.trim().length === 0) {
      return null;
    }
    const parsed = new Date(value);
    if (Number.isNaN(parsed.getTime())) {
      return null;
    }
    return parsed.toISOString();
  }
}
