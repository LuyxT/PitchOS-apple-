import { getPrisma } from '../../lib/prisma';
import { AppError } from '../../middleware/errorHandler';

// ─── Interfaces ─────────────────────────────────────────

export interface ListPlansOptions {
  limit?: number;
  cursor?: string;
  from?: string;
  to?: string;
  coachId?: string;
}

export interface CreatePlanInput {
  title: string;
  date: string;
  location?: string | null;
  mainGoal?: string | null;
  secondaryGoals?: string[];
  linkedMatchID?: string | null;
  calendarEventID?: string | null;
  teamId?: string | null;
}

export interface UpdatePlanInput {
  title?: string;
  date?: string;
  location?: string | null;
  mainGoal?: string | null;
  secondaryGoals?: string[];
  linkedMatchID?: string | null;
  calendarEventID?: string | null;
  status?: string;
  teamId?: string | null;
}

export interface PhaseInput {
  orderIndex: number;
  type: string;
  title: string;
  durationMinutes: number;
  goal?: string | null;
  intensity?: string | null;
  description?: string | null;
}

export interface ExerciseInput {
  phaseId: string;
  orderIndex: number;
  name: string;
  description?: string | null;
  durationMinutes: number;
  intensity?: string | null;
  requiredPlayers?: number | null;
  materials?: string[];
  excludedPlayerIDs?: string[];
  templateSourceID?: string | null;
}

export interface GroupInput {
  name: string;
  goal?: string | null;
  playerIDs?: string[];
  headCoachUserID?: string | null;
  assistantCoachUserID?: string | null;
}

export interface BriefingInput {
  goal?: string | null;
  coachingPoints?: string | null;
  focusPoints?: string | null;
  commonMistakes?: string | null;
  targetIntensity?: string | null;
}

export interface ParticipantInput {
  playerID: string;
  status: string;
  note?: string | null;
}

export interface StartLiveInput {
  startedAt?: string;
}

export interface LiveStateInput {
  completedPhaseIDs?: string[];
  skippedExerciseIDs?: string[];
  actualDurations?: { exerciseId: string; minutes: number }[];
}

export interface DeviationInput {
  phaseID?: string | null;
  exerciseID?: string | null;
  kind: string;
  plannedValue?: string | null;
  actualValue?: string | null;
  note?: string | null;
}

export interface ReportInput {
  plannedTotalMinutes?: number | null;
  actualTotalMinutes?: number | null;
  attendance?: unknown;
  groupFeedback?: unknown;
  playerNotes?: unknown;
  summary?: string | null;
}

export interface CalendarLinkInput {
  playerVisibleGoal?: string | null;
  playerVisibleDurationMinutes?: number | null;
}

export interface DuplicateInput {
  templateName?: string;
}

export interface ListTemplatesOptions {
  query?: string;
  cursor?: string;
  limit?: number;
}

export interface CreateTemplateInput {
  name: string;
  baseDescription?: string | null;
  defaultDuration?: number | null;
  defaultIntensity?: string | null;
  defaultRequiredPlayers?: number | null;
  defaultMaterials?: string[];
}

// ─── Plan CRUD ──────────────────────────────────────────

export async function listPlans(userId: string, options: ListPlansOptions) {
  const prisma = getPrisma();
  const take = Math.min(options.limit ?? 50, 100);

  const where: Record<string, unknown> = { userId };

  if (options.from || options.to) {
    const dateFilter: Record<string, Date> = {};
    if (options.from) dateFilter.gte = new Date(options.from);
    if (options.to) dateFilter.lte = new Date(options.to);
    where.date = dateFilter;
  }

  if (options.coachId) {
    where.userId = options.coachId;
  }

  if (options.cursor) {
    where.createdAt = { lt: new Date(options.cursor) };
  }

  const plans = await prisma.trainingPlan.findMany({
    where,
    take,
    orderBy: { createdAt: 'desc' },
  });

  const nextCursor =
    plans.length === take
      ? plans[plans.length - 1].createdAt.toISOString()
      : null;

  return {
    items: plans.map(formatPlan),
    nextCursor,
  };
}

export async function getPlanEnvelope(planId: string, userId: string) {
  const prisma = getPrisma();

  const plan = await prisma.trainingPlan.findUnique({
    where: { id: planId },
    include: {
      phases: { orderBy: { orderIndex: 'asc' } },
      exercises: { orderBy: { orderIndex: 'asc' } },
      groups: { include: { briefing: true } },
      report: true,
      availability: true,
      deviations: { orderBy: { timestamp: 'asc' } },
    },
  });

  if (!plan) {
    throw new AppError(404, 'PLAN_NOT_FOUND', 'Training plan not found');
  }
  if (plan.userId !== userId) {
    throw new AppError(403, 'FORBIDDEN', 'You do not have permission to view this plan');
  }

  return {
    plan: formatPlan(plan),
    phases: plan.phases.map(formatPhase),
    exercises: plan.exercises.map(formatExercise),
    groups: plan.groups.map(formatGroup),
    availability: plan.availability.map(formatAvailability),
    deviations: plan.deviations.map(formatDeviation),
    report: plan.report ? formatReport(plan.report) : null,
  };
}

export async function createPlan(input: CreatePlanInput, userId: string) {
  const prisma = getPrisma();

  const plan = await prisma.trainingPlan.create({
    data: {
      title: input.title,
      date: new Date(input.date),
      location: input.location ?? null,
      mainGoal: input.mainGoal ?? null,
      secondaryGoals: input.secondaryGoals ?? [],
      linkedMatchID: input.linkedMatchID ?? null,
      calendarEventID: input.calendarEventID ?? null,
      userId,
      teamId: input.teamId ?? null,
    },
  });

  return formatPlan(plan);
}

export async function updatePlan(planId: string, input: UpdatePlanInput, userId: string) {
  const prisma = getPrisma();

  const existing = await prisma.trainingPlan.findUnique({ where: { id: planId } });
  if (!existing) {
    throw new AppError(404, 'PLAN_NOT_FOUND', 'Training plan not found');
  }
  if (existing.userId !== userId) {
    throw new AppError(403, 'FORBIDDEN', 'You do not have permission to update this plan');
  }

  const data: Record<string, unknown> = {};
  if (input.title !== undefined) data.title = input.title;
  if (input.date !== undefined) data.date = new Date(input.date);
  if (input.location !== undefined) data.location = input.location;
  if (input.mainGoal !== undefined) data.mainGoal = input.mainGoal;
  if (input.secondaryGoals !== undefined) data.secondaryGoals = input.secondaryGoals;
  if (input.linkedMatchID !== undefined) data.linkedMatchID = input.linkedMatchID;
  if (input.calendarEventID !== undefined) data.calendarEventID = input.calendarEventID;
  if (input.status !== undefined) data.status = input.status;
  if (input.teamId !== undefined) data.teamId = input.teamId;

  const plan = await prisma.trainingPlan.update({
    where: { id: planId },
    data,
  });

  return formatPlan(plan);
}

export async function deletePlan(planId: string, userId: string) {
  const prisma = getPrisma();

  const existing = await prisma.trainingPlan.findUnique({ where: { id: planId } });
  if (!existing) {
    throw new AppError(404, 'PLAN_NOT_FOUND', 'Training plan not found');
  }
  if (existing.userId !== userId) {
    throw new AppError(403, 'FORBIDDEN', 'You do not have permission to delete this plan');
  }

  await prisma.trainingPlan.delete({ where: { id: planId } });
}

// ─── Phases ─────────────────────────────────────────────

export async function savePhases(planId: string, phases: PhaseInput[], userId: string) {
  const prisma = getPrisma();

  const plan = await prisma.trainingPlan.findUnique({ where: { id: planId } });
  if (!plan) {
    throw new AppError(404, 'PLAN_NOT_FOUND', 'Training plan not found');
  }
  if (plan.userId !== userId) {
    throw new AppError(403, 'FORBIDDEN', 'You do not have permission to modify this plan');
  }

  await prisma.$transaction(async (tx) => {
    await tx.trainingExercise.deleteMany({ where: { planId } });
    await tx.trainingPhase.deleteMany({ where: { planId } });
    for (const phase of phases) {
      await tx.trainingPhase.create({
        data: {
          planId,
          orderIndex: phase.orderIndex,
          type: phase.type,
          title: phase.title,
          durationMinutes: phase.durationMinutes,
          goal: phase.goal ?? null,
          intensity: phase.intensity ?? null,
          description: phase.description ?? null,
        },
      });
    }
  });

  const saved = await prisma.trainingPhase.findMany({
    where: { planId },
    orderBy: { orderIndex: 'asc' },
  });

  return saved.map(formatPhase);
}

// ─── Exercises ──────────────────────────────────────────

export async function saveExercises(planId: string, exercises: ExerciseInput[], userId: string) {
  const prisma = getPrisma();

  const plan = await prisma.trainingPlan.findUnique({ where: { id: planId } });
  if (!plan) {
    throw new AppError(404, 'PLAN_NOT_FOUND', 'Training plan not found');
  }
  if (plan.userId !== userId) {
    throw new AppError(403, 'FORBIDDEN', 'You do not have permission to modify this plan');
  }

  await prisma.$transaction(async (tx) => {
    await tx.trainingExercise.deleteMany({ where: { planId } });
    for (const ex of exercises) {
      await tx.trainingExercise.create({
        data: {
          phaseId: ex.phaseId,
          planId,
          orderIndex: ex.orderIndex,
          name: ex.name,
          description: ex.description ?? null,
          durationMinutes: ex.durationMinutes,
          intensity: ex.intensity ?? null,
          requiredPlayers: ex.requiredPlayers ?? null,
          materials: ex.materials ?? [],
          excludedPlayerIDs: ex.excludedPlayerIDs ?? [],
          templateSourceID: ex.templateSourceID ?? null,
        },
      });
    }
  });

  const saved = await prisma.trainingExercise.findMany({
    where: { planId },
    orderBy: { orderIndex: 'asc' },
  });

  return saved.map(formatExercise);
}

// ─── Exercise Templates ─────────────────────────────────

export async function createTemplate(input: CreateTemplateInput, userId: string) {
  const prisma = getPrisma();

  const template = await prisma.trainingExerciseTemplate.create({
    data: {
      name: input.name,
      baseDescription: input.baseDescription ?? null,
      defaultDuration: input.defaultDuration ?? null,
      defaultIntensity: input.defaultIntensity ?? null,
      defaultRequiredPlayers: input.defaultRequiredPlayers ?? null,
      defaultMaterials: input.defaultMaterials ?? [],
      userId,
    },
  });

  return formatTemplate(template);
}

export async function listTemplates(userId: string, options: ListTemplatesOptions) {
  const prisma = getPrisma();
  const take = Math.min(options.limit ?? 50, 100);

  const where: Record<string, unknown> = { userId };

  if (options.query) {
    where.name = { contains: options.query, mode: 'insensitive' };
  }

  if (options.cursor) {
    where.createdAt = { lt: new Date(options.cursor) };
  }

  const templates = await prisma.trainingExerciseTemplate.findMany({
    where,
    take,
    orderBy: { createdAt: 'desc' },
  });

  const nextCursor =
    templates.length === take
      ? templates[templates.length - 1].createdAt.toISOString()
      : null;

  return {
    items: templates.map(formatTemplate),
    nextCursor,
  };
}

// ─── Groups ─────────────────────────────────────────────

export async function createGroup(planId: string, input: GroupInput, userId: string) {
  const prisma = getPrisma();

  const plan = await prisma.trainingPlan.findUnique({ where: { id: planId } });
  if (!plan) {
    throw new AppError(404, 'PLAN_NOT_FOUND', 'Training plan not found');
  }
  if (plan.userId !== userId) {
    throw new AppError(403, 'FORBIDDEN', 'You do not have permission to modify this plan');
  }

  const group = await prisma.trainingGroup.create({
    data: {
      planId,
      name: input.name,
      goal: input.goal ?? null,
      playerIDs: input.playerIDs ?? [],
      headCoachUserID: input.headCoachUserID ?? null,
      assistantCoachUserID: input.assistantCoachUserID ?? null,
    },
    include: { briefing: true },
  });

  return formatGroup(group);
}

export async function updateGroup(groupId: string, input: GroupInput, userId: string) {
  const prisma = getPrisma();

  const existing = await prisma.trainingGroup.findUnique({
    where: { id: groupId },
    include: { plan: true },
  });
  if (!existing) {
    throw new AppError(404, 'GROUP_NOT_FOUND', 'Training group not found');
  }
  if (existing.plan.userId !== userId) {
    throw new AppError(403, 'FORBIDDEN', 'You do not have permission to modify this group');
  }

  const group = await prisma.trainingGroup.update({
    where: { id: groupId },
    data: {
      name: input.name,
      goal: input.goal ?? null,
      playerIDs: input.playerIDs ?? [],
      headCoachUserID: input.headCoachUserID ?? null,
      assistantCoachUserID: input.assistantCoachUserID ?? null,
    },
    include: { briefing: true },
  });

  return formatGroup(group);
}

// ─── Briefings ──────────────────────────────────────────

export async function saveGroupBriefing(groupId: string, input: BriefingInput, userId: string) {
  const prisma = getPrisma();

  const group = await prisma.trainingGroup.findUnique({
    where: { id: groupId },
    include: { plan: true },
  });
  if (!group) {
    throw new AppError(404, 'GROUP_NOT_FOUND', 'Training group not found');
  }
  if (group.plan.userId !== userId) {
    throw new AppError(403, 'FORBIDDEN', 'You do not have permission to modify this group');
  }

  const briefing = await prisma.trainingGroupBriefing.upsert({
    where: { groupId },
    create: {
      groupId,
      goal: input.goal ?? null,
      coachingPoints: input.coachingPoints ?? null,
      focusPoints: input.focusPoints ?? null,
      commonMistakes: input.commonMistakes ?? null,
      targetIntensity: input.targetIntensity ?? null,
    },
    update: {
      goal: input.goal ?? null,
      coachingPoints: input.coachingPoints ?? null,
      focusPoints: input.focusPoints ?? null,
      commonMistakes: input.commonMistakes ?? null,
      targetIntensity: input.targetIntensity ?? null,
    },
  });

  return formatBriefing(briefing);
}

// ─── Participants / Availability ────────────────────────

export async function saveParticipants(planId: string, participants: ParticipantInput[], userId: string) {
  const prisma = getPrisma();

  const plan = await prisma.trainingPlan.findUnique({ where: { id: planId } });
  if (!plan) {
    throw new AppError(404, 'PLAN_NOT_FOUND', 'Training plan not found');
  }
  if (plan.userId !== userId) {
    throw new AppError(403, 'FORBIDDEN', 'You do not have permission to modify this plan');
  }

  await prisma.$transaction(async (tx) => {
    await tx.trainingAvailability.deleteMany({ where: { planId } });
    for (const p of participants) {
      await tx.trainingAvailability.create({
        data: {
          planId,
          playerID: p.playerID,
          status: p.status,
          note: p.note ?? null,
        },
      });
    }
  });

  const saved = await prisma.trainingAvailability.findMany({ where: { planId } });
  return saved.map(formatAvailability);
}

// ─── Live Mode ──────────────────────────────────────────

export async function startLive(planId: string, input: StartLiveInput, userId: string) {
  const prisma = getPrisma();

  const plan = await prisma.trainingPlan.findUnique({ where: { id: planId } });
  if (!plan) {
    throw new AppError(404, 'PLAN_NOT_FOUND', 'Training plan not found');
  }
  if (plan.userId !== userId) {
    throw new AppError(403, 'FORBIDDEN', 'You do not have permission to modify this plan');
  }

  const updated = await prisma.trainingPlan.update({
    where: { id: planId },
    data: { status: 'live' },
  });

  return formatPlan(updated);
}

export async function saveLiveState(planId: string, input: LiveStateInput, userId: string) {
  const prisma = getPrisma();

  const plan = await prisma.trainingPlan.findUnique({ where: { id: planId } });
  if (!plan) {
    throw new AppError(404, 'PLAN_NOT_FOUND', 'Training plan not found');
  }
  if (plan.userId !== userId) {
    throw new AppError(403, 'FORBIDDEN', 'You do not have permission to modify this plan');
  }

  // Mark phases as completed
  if (Array.isArray(input.completedPhaseIDs) && input.completedPhaseIDs.length > 0) {
    for (const phaseId of input.completedPhaseIDs) {
      await prisma.trainingPhase.updateMany({
        where: { id: phaseId, planId },
        data: { isCompletedLive: true },
      });
    }
  }

  // Mark exercises as skipped
  if (Array.isArray(input.skippedExerciseIDs) && input.skippedExerciseIDs.length > 0) {
    for (const exerciseId of input.skippedExerciseIDs) {
      await prisma.trainingExercise.updateMany({
        where: { id: exerciseId, planId },
        data: { isSkippedLive: true },
      });
    }
  }

  // Update actual durations
  if (Array.isArray(input.actualDurations) && input.actualDurations.length > 0) {
    for (const dur of input.actualDurations) {
      await prisma.trainingExercise.updateMany({
        where: { id: dur.exerciseId, planId },
        data: { actualDurationMinutes: dur.minutes },
      });
    }
  }

  // Return the full envelope
  return getPlanEnvelope(planId, userId);
}

export async function createDeviation(planId: string, input: DeviationInput, userId: string) {
  const prisma = getPrisma();

  const plan = await prisma.trainingPlan.findUnique({ where: { id: planId } });
  if (!plan) {
    throw new AppError(404, 'PLAN_NOT_FOUND', 'Training plan not found');
  }
  if (plan.userId !== userId) {
    throw new AppError(403, 'FORBIDDEN', 'You do not have permission to modify this plan');
  }

  const deviation = await prisma.trainingLiveDeviation.create({
    data: {
      planId,
      phaseID: input.phaseID ?? null,
      exerciseID: input.exerciseID ?? null,
      kind: input.kind,
      plannedValue: input.plannedValue ?? null,
      actualValue: input.actualValue ?? null,
      note: input.note ?? null,
    },
  });

  return formatDeviation(deviation);
}

// ─── Report ─────────────────────────────────────────────

export async function saveReport(planId: string, input: ReportInput, userId: string) {
  const prisma = getPrisma();

  const plan = await prisma.trainingPlan.findUnique({ where: { id: planId } });
  if (!plan) {
    throw new AppError(404, 'PLAN_NOT_FOUND', 'Training plan not found');
  }
  if (plan.userId !== userId) {
    throw new AppError(403, 'FORBIDDEN', 'You do not have permission to modify this plan');
  }

  const report = await prisma.trainingReport.upsert({
    where: { planId },
    create: {
      planId,
      plannedTotalMinutes: input.plannedTotalMinutes ?? null,
      actualTotalMinutes: input.actualTotalMinutes ?? null,
      attendance: input.attendance ?? [],
      groupFeedback: input.groupFeedback ?? [],
      playerNotes: input.playerNotes ?? [],
      summary: input.summary ?? null,
    },
    update: {
      plannedTotalMinutes: input.plannedTotalMinutes ?? null,
      actualTotalMinutes: input.actualTotalMinutes ?? null,
      attendance: input.attendance ?? [],
      groupFeedback: input.groupFeedback ?? [],
      playerNotes: input.playerNotes ?? [],
      summary: input.summary ?? null,
      generatedAt: new Date(),
    },
  });

  return formatReport(report);
}

export async function getReport(planId: string, userId: string) {
  const prisma = getPrisma();

  const plan = await prisma.trainingPlan.findUnique({ where: { id: planId } });
  if (!plan) {
    throw new AppError(404, 'PLAN_NOT_FOUND', 'Training plan not found');
  }
  if (plan.userId !== userId) {
    throw new AppError(403, 'FORBIDDEN', 'You do not have permission to view this plan');
  }

  const report = await prisma.trainingReport.findUnique({ where: { planId } });
  if (!report) {
    throw new AppError(404, 'REPORT_NOT_FOUND', 'Training report not found');
  }

  return formatReport(report);
}

// ─── Calendar Link ──────────────────────────────────────

export async function linkCalendar(planId: string, input: CalendarLinkInput, userId: string) {
  const prisma = getPrisma();

  const plan = await prisma.trainingPlan.findUnique({ where: { id: planId } });
  if (!plan) {
    throw new AppError(404, 'PLAN_NOT_FOUND', 'Training plan not found');
  }
  if (plan.userId !== userId) {
    throw new AppError(403, 'FORBIDDEN', 'You do not have permission to modify this plan');
  }

  const durationMinutes = input.playerVisibleDurationMinutes ?? 90;

  const event = await prisma.calendarEvent.create({
    data: {
      title: plan.title,
      startDate: plan.date,
      endDate: new Date(plan.date.getTime() + durationMinutes * 60 * 1000),
      location: plan.location,
      linkedTrainingPlanID: plan.id,
      eventKind: 'training',
      playerVisibleGoal: input.playerVisibleGoal ?? null,
      playerVisibleDurationMinutes: input.playerVisibleDurationMinutes ?? null,
      userId,
    },
  });

  // Link the calendar event back to the plan
  await prisma.trainingPlan.update({
    where: { id: planId },
    data: { calendarEventID: event.id },
  });

  return {
    id: event.id,
    title: event.title,
    startDate: event.startDate.toISOString(),
    endDate: event.endDate.toISOString(),
    location: event.location,
    linkedTrainingPlanID: event.linkedTrainingPlanID,
    eventKind: event.eventKind,
    playerVisibleGoal: event.playerVisibleGoal,
    playerVisibleDurationMinutes: event.playerVisibleDurationMinutes,
    userId: event.userId,
    createdAt: event.createdAt.toISOString(),
    updatedAt: event.updatedAt.toISOString(),
  };
}

// ─── Duplicate ──────────────────────────────────────────

export async function duplicatePlan(planId: string, input: DuplicateInput, userId: string) {
  const prisma = getPrisma();

  const source = await prisma.trainingPlan.findUnique({
    where: { id: planId },
    include: {
      phases: { orderBy: { orderIndex: 'asc' } },
      exercises: { orderBy: { orderIndex: 'asc' } },
      groups: { include: { briefing: true } },
    },
  });

  if (!source) {
    throw new AppError(404, 'PLAN_NOT_FOUND', 'Training plan not found');
  }
  if (source.userId !== userId) {
    throw new AppError(403, 'FORBIDDEN', 'You do not have permission to duplicate this plan');
  }

  // Create the new plan
  const newPlan = await prisma.trainingPlan.create({
    data: {
      title: input.templateName ?? `${source.title} (Copy)`,
      date: source.date,
      location: source.location,
      mainGoal: source.mainGoal,
      secondaryGoals: source.secondaryGoals,
      linkedMatchID: source.linkedMatchID,
      status: 'draft',
      userId,
      teamId: source.teamId,
    },
  });

  // Map old phase IDs to new phase IDs so exercises can reference them
  const phaseIdMap = new Map<string, string>();

  for (const phase of source.phases) {
    const newPhase = await prisma.trainingPhase.create({
      data: {
        planId: newPlan.id,
        orderIndex: phase.orderIndex,
        type: phase.type,
        title: phase.title,
        durationMinutes: phase.durationMinutes,
        goal: phase.goal,
        intensity: phase.intensity,
        description: phase.description,
        isCompletedLive: false,
      },
    });
    phaseIdMap.set(phase.id, newPhase.id);
  }

  // Duplicate exercises with mapped phase IDs
  for (const exercise of source.exercises) {
    const newPhaseId = phaseIdMap.get(exercise.phaseId);
    if (!newPhaseId) continue;

    await prisma.trainingExercise.create({
      data: {
        phaseId: newPhaseId,
        planId: newPlan.id,
        orderIndex: exercise.orderIndex,
        name: exercise.name,
        description: exercise.description,
        durationMinutes: exercise.durationMinutes,
        intensity: exercise.intensity,
        requiredPlayers: exercise.requiredPlayers,
        materials: exercise.materials,
        excludedPlayerIDs: exercise.excludedPlayerIDs,
        templateSourceID: exercise.templateSourceID,
        isSkippedLive: false,
        actualDurationMinutes: null,
      },
    });
  }

  // Duplicate groups and briefings
  for (const group of source.groups) {
    const newGroup = await prisma.trainingGroup.create({
      data: {
        planId: newPlan.id,
        name: group.name,
        goal: group.goal,
        playerIDs: group.playerIDs,
        headCoachUserID: group.headCoachUserID,
        assistantCoachUserID: group.assistantCoachUserID,
      },
    });

    if (group.briefing) {
      await prisma.trainingGroupBriefing.create({
        data: {
          groupId: newGroup.id,
          goal: group.briefing.goal,
          coachingPoints: group.briefing.coachingPoints,
          focusPoints: group.briefing.focusPoints,
          commonMistakes: group.briefing.commonMistakes,
          targetIntensity: group.briefing.targetIntensity,
        },
      });
    }
  }

  return formatPlan(newPlan);
}

// ─── Response Formatters ────────────────────────────────

function formatPlan(plan: {
  id: string;
  title: string;
  date: Date;
  location: string | null;
  mainGoal: string | null;
  secondaryGoals: string[];
  status: string;
  linkedMatchID: string | null;
  calendarEventID: string | null;
  userId: string;
  teamId: string | null;
  createdAt: Date;
  updatedAt: Date;
}) {
  return {
    id: plan.id,
    title: plan.title,
    date: plan.date.toISOString(),
    location: plan.location,
    mainGoal: plan.mainGoal,
    secondaryGoals: plan.secondaryGoals,
    status: plan.status,
    linkedMatchID: plan.linkedMatchID,
    calendarEventID: plan.calendarEventID,
    userId: plan.userId,
    teamId: plan.teamId,
    createdAt: plan.createdAt.toISOString(),
    updatedAt: plan.updatedAt.toISOString(),
  };
}

function formatPhase(phase: {
  id: string;
  planId: string;
  orderIndex: number;
  type: string;
  title: string;
  durationMinutes: number;
  goal: string | null;
  intensity: string | null;
  description: string | null;
  isCompletedLive: boolean;
  createdAt: Date;
  updatedAt: Date;
}) {
  return {
    id: phase.id,
    planId: phase.planId,
    orderIndex: phase.orderIndex,
    type: phase.type,
    title: phase.title,
    durationMinutes: phase.durationMinutes,
    goal: phase.goal,
    intensity: phase.intensity,
    description: phase.description,
    isCompletedLive: phase.isCompletedLive,
    createdAt: phase.createdAt.toISOString(),
    updatedAt: phase.updatedAt.toISOString(),
  };
}

function formatExercise(exercise: {
  id: string;
  phaseId: string;
  planId: string;
  orderIndex: number;
  name: string;
  description: string | null;
  durationMinutes: number;
  intensity: string | null;
  requiredPlayers: number | null;
  materials: string[];
  excludedPlayerIDs: string[];
  templateSourceID: string | null;
  isSkippedLive: boolean;
  actualDurationMinutes: number | null;
  createdAt: Date;
  updatedAt: Date;
}) {
  return {
    id: exercise.id,
    phaseId: exercise.phaseId,
    planId: exercise.planId,
    orderIndex: exercise.orderIndex,
    name: exercise.name,
    description: exercise.description,
    durationMinutes: exercise.durationMinutes,
    intensity: exercise.intensity,
    requiredPlayers: exercise.requiredPlayers,
    materials: exercise.materials,
    excludedPlayerIDs: exercise.excludedPlayerIDs,
    templateSourceID: exercise.templateSourceID,
    isSkippedLive: exercise.isSkippedLive,
    actualDurationMinutes: exercise.actualDurationMinutes,
    createdAt: exercise.createdAt.toISOString(),
    updatedAt: exercise.updatedAt.toISOString(),
  };
}

function formatGroup(group: {
  id: string;
  planId: string;
  name: string;
  goal: string | null;
  playerIDs: string[];
  headCoachUserID: string | null;
  assistantCoachUserID: string | null;
  createdAt: Date;
  updatedAt: Date;
  briefing?: {
    id: string;
    groupId: string;
    goal: string | null;
    coachingPoints: string | null;
    focusPoints: string | null;
    commonMistakes: string | null;
    targetIntensity: string | null;
    createdAt: Date;
    updatedAt: Date;
  } | null;
}) {
  return {
    id: group.id,
    planId: group.planId,
    name: group.name,
    goal: group.goal,
    playerIDs: group.playerIDs,
    headCoachUserID: group.headCoachUserID,
    assistantCoachUserID: group.assistantCoachUserID,
    briefing: group.briefing ? formatBriefing(group.briefing) : null,
    createdAt: group.createdAt.toISOString(),
    updatedAt: group.updatedAt.toISOString(),
  };
}

function formatBriefing(briefing: {
  id: string;
  groupId: string;
  goal: string | null;
  coachingPoints: string | null;
  focusPoints: string | null;
  commonMistakes: string | null;
  targetIntensity: string | null;
  createdAt: Date;
  updatedAt: Date;
}) {
  return {
    id: briefing.id,
    groupId: briefing.groupId,
    goal: briefing.goal,
    coachingPoints: briefing.coachingPoints,
    focusPoints: briefing.focusPoints,
    commonMistakes: briefing.commonMistakes,
    targetIntensity: briefing.targetIntensity,
    createdAt: briefing.createdAt.toISOString(),
    updatedAt: briefing.updatedAt.toISOString(),
  };
}

function formatAvailability(a: {
  id: string;
  planId: string;
  playerID: string;
  status: string;
  note: string | null;
}) {
  return {
    id: a.id,
    planId: a.planId,
    playerID: a.playerID,
    status: a.status,
    note: a.note,
  };
}

function formatDeviation(d: {
  id: string;
  planId: string;
  phaseID: string | null;
  exerciseID: string | null;
  kind: string;
  plannedValue: string | null;
  actualValue: string | null;
  note: string | null;
  timestamp: Date;
}) {
  return {
    id: d.id,
    planId: d.planId,
    phaseID: d.phaseID,
    exerciseID: d.exerciseID,
    kind: d.kind,
    plannedValue: d.plannedValue,
    actualValue: d.actualValue,
    note: d.note,
    timestamp: d.timestamp.toISOString(),
  };
}

function formatReport(report: {
  id: string;
  planId: string;
  generatedAt: Date;
  plannedTotalMinutes: number | null;
  actualTotalMinutes: number | null;
  attendance: unknown;
  groupFeedback: unknown;
  playerNotes: unknown;
  summary: string | null;
  createdAt: Date;
  updatedAt: Date;
}) {
  return {
    id: report.id,
    planId: report.planId,
    generatedAt: report.generatedAt.toISOString(),
    plannedTotalMinutes: report.plannedTotalMinutes,
    actualTotalMinutes: report.actualTotalMinutes,
    attendance: report.attendance,
    groupFeedback: report.groupFeedback,
    playerNotes: report.playerNotes,
    summary: report.summary,
    createdAt: report.createdAt.toISOString(),
    updatedAt: report.updatedAt.toISOString(),
  };
}

function formatTemplate(t: {
  id: string;
  name: string;
  baseDescription: string | null;
  defaultDuration: number | null;
  defaultIntensity: string | null;
  defaultRequiredPlayers: number | null;
  defaultMaterials: string[];
  userId: string;
  createdAt: Date;
  updatedAt: Date;
}) {
  return {
    id: t.id,
    name: t.name,
    baseDescription: t.baseDescription,
    defaultDuration: t.defaultDuration,
    defaultIntensity: t.defaultIntensity,
    defaultRequiredPlayers: t.defaultRequiredPlayers,
    defaultMaterials: t.defaultMaterials,
    userId: t.userId,
    createdAt: t.createdAt.toISOString(),
    updatedAt: t.updatedAt.toISOString(),
  };
}
